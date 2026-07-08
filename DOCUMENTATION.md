# Implementing Secure IAM for NexaCore Solutions with Terraform

<img width="720" height="248" alt="image" src="https://github.com/user-attachments/assets/be48a297-e3db-4302-b21f-df0de25d1059" />


## 📌 Current Situation / Challenge

NexaCore Solutions (a hypothetical company) had around 10 employees, all sharing a single AWS root account. Credentials were being passed around through tools like Microsoft Teams and Slack, creating a major security risk and zero accountability.

Common issues with this setup:

- No visibility into who is doing what
- High chance of credential leaks
- Full access exposure if credentials are compromised
- Zero separation of duties between teams

## 🎯 Goal

My objective was to redesign the access model by introducing proper IAM practices. This included:

- Creating individual user accounts
- Implementing role-based access control (RBAC)
- Enforcing MFA for stronger security
- Adding audit logging so activity is traceable

The aim was to move from an insecure, shared-access setup to a structured and scalable system aligned with real-world DevOps and security best practices.

## 🧠 What We Will Learn

Through this project, I aim to strengthen my skills in:

- IAM group/user/policy design in Terraform
- Writing least-privilege JSON policies with `jsonencode()`
- Scaling repetitive resources with `for_each`
- Configuring CloudTrail for account-wide audit logging
- Testing IAM policies against real AWS resources

## 🛠️ Project Tasks

**1. Plan the Access Model**
- Map out what each team actually needs (not what's convenient to grant)
- Define per-role boundaries before writing any Terraform

**2. Build the IAM Structure**
- Create IAM groups per team
- Create IAM users with `for_each`
- Attach users to groups
- Write least-privilege policies per group
- Enforce MFA on every group

**3. Add Auditing**
- Create a dedicated S3 bucket for logs
- Configure a CloudTrail trail
- Attach a bucket policy so CloudTrail can actually write to it

**4. Deploy and Test**
- `terraform validate` / `plan` / `apply`
- Log in as each user and confirm allowed actions succeed and restricted actions are denied
- Verify activity shows up correctly in CloudTrail

**Flow:**

```
Terraform (iam-groups.tf, iam-user.tf, iam-policy.tf, main.tf)
        │
        ▼
IAM Groups (developers, operations, finance, analysts)
        │
        ▼
IAM Users → for_each → Group Membership
        │
        ▼
Least-Privilege Policies + MFA Enforcement
        │
        ▼
CloudTrail → S3 (nexacore-logs-<account-id>)
```

## Why This Project Matters

This kind of setup — one shared root account, credentials in chat — is more common than people think in early-stage environments, and it introduces serious risk. By implementing IAM correctly, the environment moves toward something secure, auditable, and production-ready.

## Final Outcome

By the end of this project:

- Shared root credentials were fully eliminated
- 10/10 users had individual accounts enforced with MFA
- Every team had a least-privilege policy matching its actual responsibilities
- CloudTrail was capturing full account activity for auditing

---

## 1. Planning & Research

Before writing a single resource block, I mapped out what each team at NexaCore actually needs, instead of guessing permissions or defaulting to broad access.

**Access Design Overview**
<img width="720" height="228" alt="image" src="https://github.com/user-attachments/assets/b364b5b3-9aa5-401f-aa29-bf467fe279fd" />


- **Developers (4 users)** — EC2 and S3 access scoped to development resources only, plus read-only CloudWatch logs for debugging. No production access.
- **Operations (2 users)** — Full infrastructure management (EC2, RDS, CloudWatch, logs, S3), but explicitly no ability to modify IAM policies, to prevent privilege escalation.
- **Finance (1 user)** — Billing/cost visibility and read-only access, using AWS managed policies rather than a custom one.
- **Analysts (3 users)** — Read-only access to specific S3 data and RDS metadata. No write or infrastructure permissions.

This step matters more than it looks. Instead of guessing permissions, it forces you to define responsibilities per team, avoid over-permissioning, and make the resulting Terraform intentional rather than random. Bad IAM design is one of the biggest security risks in production — giving developers access to prod, letting operations edit IAM policies, or giving analysts write access are all real incidents waiting to happen.

## 2. Building the IAM Structure

### Step 1: Creating IAM Groups

I started with a simple `iam-groups.tf` file defining the four core groups:

```hcl
# IAM groups
resource "aws_iam_group" "developers" {
  name = "developers"
}

resource "aws_iam_group" "operations" {
  name = "operations"
}

resource "aws_iam_group" "finance" {
  name = "finance"
}

resource "aws_iam_group" "analysts" {
  name = "analysts"
}
```

Each group represents a different access pattern, which makes it much easier to manage permissions in a structured way instead of assigning access directly to individual users. Using groups as the starting point avoids one of the most common IAM mistakes: attaching permissions straight to users. By attaching policies to groups instead, access scales cleanly, onboarding is simpler, and permissions stay consistent across everyone in the same role.

### Step 2: Creating IAM Users (the smart way)

My first instinct was to define each user individually:

```hcl
resource "aws_iam_user" "dev_1" {
  name = "dev-1"
}
resource "aws_iam_user" "dev_2" {
  name = "dev-2"
}
# ...repeat this multiple times
```

That works for a couple of users, but it's repetitive, hard to maintain, and easy to get wrong (typos, missing users, inconsistencies) the moment a team grows. This is exactly the kind of situation `for_each` was built for:

```hcl
# IAM Users

# Developers
resource "aws_iam_user" "developers" {
  for_each = toset(["dev-1", "dev-2", "dev-3", "dev-4"])
  name     = each.key
}

# Operations
resource "aws_iam_user" "operations" {
  for_each = toset(["ops-1", "ops-2"])
  name     = each.key
}

# Finance
resource "aws_iam_user" "finance" {
  name = "finance-1"
}

# Analysts
resource "aws_iam_user" "analysts" {
  for_each = toset(["analyst-1", "analyst-2", "analyst-3"])
  name     = each.key
}
```

`for_each` takes each item in the set and creates a separate IAM user for it, but each one is still tracked as its own resource in state — meaning any single user can be modified or destroyed independently. One block of code instead of many, and onboarding a new hire becomes a one-line change to a list instead of a new resource block.

### Step 3: Assigning Users to Groups

Since the users were already created with `for_each`, I reused that same structure to wire up group membership dynamically:

```hcl
resource "aws_iam_user_group_membership" "dev_membership" {
  for_each = aws_iam_user.developers
  user     = each.value.name
  groups   = [aws_iam_group.developers.name]
}

resource "aws_iam_user_group_membership" "ops_membership" {
  for_each = aws_iam_user.operations
  user     = each.value.name
  groups   = [aws_iam_group.operations.name]
}

resource "aws_iam_user_group_membership" "finance_membership" {
  user   = aws_iam_user.finance.name
  groups = [aws_iam_group.finance.name]
}

resource "aws_iam_user_group_membership" "analyst_membership" {
  for_each = aws_iam_user.analysts
  user     = each.value.name
  groups   = [aws_iam_group.analysts.name]
}
```

Breaking it down: `for_each = aws_iam_user.developers` loops through every developer user already created, `each.value.name` pulls the username, and `groups = [...]` assigns that user to the right group. In production you never want to manage permissions per-user — you assign permissions to groups, then assign users to groups. A new developer joining just means adding a name to a list; nobody touches permissions directly.

### Step 4: Writing IAM Policies
<img width="720" height="228" alt="image" src="https://github.com/user-attachments/assets/729f6270-1d71-4148-b729-be86ea16d4c1" />


With groups and users in place, the next step was defining what each group can actually do. Groups without policies are just empty containers — the policy is what gives access its shape.

**MFA enforcement (attached to every group):**

```hcl
resource "aws_iam_policy" "require_mfa" {
  name = "RequireMFA"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowUsersToManageMFA"
        Effect = "Allow"
        Action = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ChangePassword"
        ]
        Resource = [
          "arn:aws:iam::*:user/$${aws:username}",
          "arn:aws:iam::*:mfa/$${aws:username}"
        ]
      }
    ]
  })
}
```

**Developer policy** — scoped to development resources, with a region condition on launching instances and a tag condition on start/stop/reboot:

```hcl
resource "aws_iam_policy" "dev_policy" {
  name = "DeveloperAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowDescribeEC2"
        Effect   = "Allow"
        Action   = ["ec2:Describe*"]
        Resource = "*"
      },
      {
        Sid    = "AllowDevEC2Launch"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateTags"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "us-east-2"
          }
        }
      },
      {
        Sid    = "AllowDevEC2Actions"
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RebootInstances"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/Environment" = "development"
          }
        }
      },
      {
        Sid    = "AllowS3ConsoleAccess"
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowDevS3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::nexacore-*-dev",
          "arn:aws:s3:::nexacore-*-dev/*"
        ]
      }
    ]
  })
}
```

**Operations policy** — broad infrastructure access, but no IAM write permissions:

```hcl
resource "aws_iam_policy" "ops_policy" {
  name = "OperationsAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "rds:*",
          "cloudwatch:*",
          "logs:*",
          "s3:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetUser",
          "iam:ListUsers"
        ]
        Resource = "*"
      }
    ]
  })
}
```

**Analyst policy** — read-only, scoped to a single analytics bucket and RDS metadata:

```hcl
resource "aws_iam_policy" "analyst_policy" {
  name = "AnalystReadOnly"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowS3ConsoleAccess"
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets", "s3:GetBucketLocation"]
        Resource = "*"
      },
      {
        Sid    = "AllowAnalystS3Read"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::nexacore-analytics-data",
          "arn:aws:s3:::nexacore-analytics-data/*"
        ]
      },
      {
        Sid      = "AllowRDSDescribe"
        Effect   = "Allow"
        Action   = ["rds:DescribeDBInstances"]
        Resource = "*"
      }
    ]
  })
}
```

**Finance** intentionally has no custom policy — the AWS managed `job-function/Billing` and `ReadOnlyAccess` policies already covered the requirement, so writing a custom one would have just duplicated what AWS already maintains.

Policies are attached at the group level in `iam-groups.tf`:

```hcl
resource "aws_iam_group_policy_attachment" "dev_ec2" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.dev_policy.arn
}
resource "aws_iam_group_policy_attachment" "dev_logs" {
  group      = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess"
}
resource "aws_iam_group_policy_attachment" "ops_access" {
  group      = aws_iam_group.operations.name
  policy_arn = aws_iam_policy.ops_policy.arn
}
resource "aws_iam_group_policy_attachment" "finance_billing" {
  group      = aws_iam_group.finance.name
  policy_arn = "arn:aws:iam::aws:policy/job-function/Billing"
}
resource "aws_iam_group_policy_attachment" "finance_readonly" {
  group      = aws_iam_group.finance.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
resource "aws_iam_group_policy_attachment" "analyst_readonly" {
  group      = aws_iam_group.analysts.name
  policy_arn = aws_iam_policy.analyst_policy.arn
}

# MFA enforcement for all groups
resource "aws_iam_group_policy_attachment" "dev_mfa" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.require_mfa.arn
}
resource "aws_iam_group_policy_attachment" "ops_mfa" {
  group      = aws_iam_group.operations.name
  policy_arn = aws_iam_policy.require_mfa.arn
}
resource "aws_iam_group_policy_attachment" "finance_mfa" {
  group      = aws_iam_group.finance.name
  policy_arn = aws_iam_policy.require_mfa.arn
}
resource "aws_iam_group_policy_attachment" "analyst_mfa" {
  group      = aws_iam_group.analysts.name
  policy_arn = aws_iam_policy.require_mfa.arn
}
```

Using `jsonencode()` keeps the whole policy document inside the `.tf` file instead of a separate JSON file, which improves readability and avoids formatting mistakes. `Resource = "*"` is fine for learning, but production environments generally need tighter, resource-scoped ARNs — which is why the developer and analyst policies above are scoped to specific bucket name patterns rather than left wide open.

### Step 5: Account-Wide Password Policy

Alongside per-group policies, I also enforced a strict password policy at the account level so credentials couldn't be weak even before MFA kicks in:

```hcl
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_numbers                = true
  require_uppercase_characters   = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 5
}
```

## 3. Setting Up CloudTrail for Auditing

IAM controls what users *can* do. CloudTrail answers a different question: what did they *actually* do. Access control without visibility is incomplete — even correctly configured permissions are unverifiable without a log of behavior.

**S3 bucket for logs**, named with the account ID to guarantee global uniqueness:

```hcl
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "cloudtrail" {
  bucket = "nexacore-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**The trail itself**, spanning all regions and services, with log file validation enabled:

```hcl
resource "aws_cloudtrail" "main" {
  name                          = "nexacore-audit-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}
```

**Common pitfall:** CloudTrail cannot write to a bucket unless the bucket explicitly allows it. The trail can be created successfully and still silently deliver zero logs if this policy is missing:

```hcl
data "aws_iam_policy_document" "cloudtrail_policy" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_policy.json
}
```

This grants CloudTrail's service principal exactly two things: permission to read the bucket ACL, and permission to write log objects — nothing broader. Note the explicit `depends_on` on the trail resource, which forces Terraform to create the bucket policy before the trail so log delivery works from the very first run.

I also wired up an SNS topic so security-relevant activity could page someone rather than just sitting in a log bucket:

```hcl
resource "aws_sns_topic" "security_alerts" {
  name = "security-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
```

## 4. Deployment

With groups, users, policies, the password policy, and CloudTrail defined, the last step is deploying through Terraform:

```bash
terraform validate
terraform plan
terraform apply
```
<img width="488" height="636" alt="image" src="https://github.com/user-attachments/assets/e2ef18d0-7b04-46f6-82a8-e57a06912213" />

`validate` catches syntax and reference errors before anything touches AWS. `plan` shows exactly what will be created or changed, which matters most here since IAM mistakes are the kind of thing you want to catch before they're live. `apply` then creates the users, groups, memberships, policies, CloudTrail trail, and S3 buckets in one pass.

Sensitive input (the alert email, and a placeholder DB password variable reserved for a future RDS instance) is kept out of version control via `terraform.tfvars`, using `terraform.tvars.example` as the template:

```hcl
# Copy to terraform.tfvars and update with your values

alert_email = "your-email@example.com"
aws_region  = "us-east-1"
```

Using Terraform instead of clicking through the console makes the whole IAM setup repeatable, version-controlled, easy to audit, and easy to rebuild from scratch if the account ever needed to be recreated.
<img width="490" height="393" alt="image" src="https://github.com/user-attachments/assets/e78fe7df-4af6-48d1-adf6-58214627dda4" />


## 5. Testing
<img width="514" height="374" alt="image" src="https://github.com/user-attachments/assets/6d3341de-836a-4048-9d56-cbb8efee6645" />


After deployment, the real work is confirming access controls behave exactly as designed — both what's allowed and what's denied.


**Test plan by role:**

- **Developers** — start/stop EC2 in development → allowed; start production instances → denied; upload to `nexacore-*-dev` buckets → allowed; access production buckets → denied.
- **Operations** — manage infrastructure broadly, including actions like deleting an RDS instance → allowed; modify IAM policies → denied.
- **Finance** — view the billing dashboard → allowed; start an EC2 instance → denied.
- **Analysts** — list buckets and read from `nexacore-analytics-data` → allowed; read other buckets, or write/delete/create objects anywhere → denied.

I logged in as each user individually and validated both sides of that matrix against real AWS resources, confirming MFA registration succeeded for every account and that denied actions actually surfaced as `AccessDenied` rather than silently failing for an unrelated reason.

## Monitoring with CloudTrail
<img width="1908" height="862" alt="image" src="https://github.com/user-attachments/assets/03bcedf9-180b-4771-943f-65616a252e49" />


Once access controls were live, CloudTrail became the way to verify them rather than just trust them. Reviewing the logs confirmed:

- Users were only touching resources they were permitted to
- Denied actions were showing up as denied events, not disappearing
- No unexpected activity was occurring outside each role's boundary

For example, a developer attempting to reach production resources showed up as a denied event in CloudTrail, and finance's billing access logged correctly as read-only. This closes the loop: IAM defines what's allowed, CloudTrail proves what happened.

## 📚 Key Lessons Learned

**1. Start Small, Test Often**
Building and testing one policy at a time made it far easier to catch issues early instead of debugging a tangle of policies all at once.

**2. IAM Policy Evaluation Is More Complex Than It Looks**
The evaluation order matters: an explicit Deny always wins, an explicit Allow grants access only if nothing denies it, and an implicit deny is the default when nothing matches at all.

**3. Use the AWS Policy Simulator**
Testing policies against the simulator before deploying them caught issues without needing to apply anything to a live account first.

**4. Documentation Is Critical**
Clear documentation isn't just for the current setup — it keeps future changes consistent and gives anyone else touching the account a reference for why access is structured the way it is.

## 📊 Results After Implementation

- Shared root credentials completely eliminated
- MFA adoption: 0% → 100% (10/10 users)
- Audit visibility: none → full account activity via CloudTrail
- Permission model: over-privileged admin access → least privilege per role
- User onboarding: 1+ days → roughly 15 minutes
- 0 root account logins after implementation
- 0 security incidents observed post-rollout

## Final Thoughts

Security isn't just about restricting access — it's about giving people exactly what they need to do their jobs, nothing more, nothing less. That's what least privilege actually means in practice.

The hardest part of this project wasn't Terraform — writing the code is straightforward once the logic is clear. The hard part was translating NexaCore's actual business requirements into precise IAM policies: figuring out which permissions achieve the goal without over-granting anything. That planning work, done before a single resource block was written, is what shaped the rest of the implementation.

## Skills Demonstrated

- AWS IAM (users, groups, policies, MFA enforcement)
- Terraform / Infrastructure as Code
- Least-privilege policy design with `jsonencode()`
- Scalable resource management with `for_each`
- AWS CloudTrail configuration and S3 bucket policies for log delivery
- AWS SNS for alerting
- IAM account password policy hardening
- Manual + Policy Simulator–based access testing

## Reference

Full narrative write-up: [Implementation Guide: NexaCore Solutions IAM Security Project](https://medium.com/@a.arale86/implementation-guide-nexacore-solutions-iam-security-project-64842b02ce50)

Code repository: [abdiarale86/Nexacore-IAM-Security-Project](https://github.com/abdiarale86/Nexacore-IAM-Security-Project)
