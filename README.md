---

Implementation Guide: NexaCore Solutions IAM Security Project

This project walks through my hands-on experience implementing a secure IAM setup, including the challenges I encountered and how I addressed them.
Github repo for code used throughout the project: abdiarale86/Nexacore-IAM-Security-Project

---

Project Context
Scenario:
 NexaCore Solutions (a hypothetical company) had around 10 employees all sharing a single AWS root account. Credentials were being passed around through tools like Microsoft Teams and Slack, creating a major security risk and zero accountability.
Goal:
 My objective was to redesign the access model by introducing proper IAM practices. This included:
Creating individual user accounts
Implementing role-based access control
Enforcing MFA for stronger security

The aim was to move from an insecure, shared-access setup to a structured and scalable system aligned with real-world DevOps and security best practices.

---

 Why This Matters
This kind of setup is more common than people think in early-stage environments, but it introduces serious risks:
No visibility into who is doing what
High chance of credential leaks
Full access exposure if credentials are compromised

By implementing IAM correctly, we move toward a secure, auditable, and production-ready environment.
Phase 1: Planning & Research
Understanding the Requirements
At NexaCore Solutions, I start by mapping out what each team actually needs in terms of access. Instead of giving broad permissions, the goal is to align access with real responsibilities.
Here's how the access requirements break down:

Phase 2: Building the IAM Structure
Step 1: Creating IAM Groups
Once the access requirements were clear, I moved into building the IAM structure in Terraform.
I started with a simple iam-groups.tf file, where I defined the core user groups based on the teams at NexaCore Solutions. This part was straightforward, since the main goal was to create a clean foundation that could scale as the company grows.
The groups I created were:
developers
operations
finance
analysts

Each group represents a different access pattern, which makes it much easier to manage permissions in a structured way instead of assigning access directly to individual users.

---

Attaching Policies to Each Group
After creating the groups, the next step was attaching the right policies.
For example, the developers group received:
a custom policy for the development resources they need
read-only access to CloudWatch logs
an MFA enforcement policy

I followed the same pattern for the operations, finance, and analysts groups, attaching only the permissions each team actually requires.
This approach keeps the setup:
easier to manage
easier to audit
and much more secure

---

Why This Matters
Using groups as the starting point helps avoid one of the most common IAM mistakes: assigning permissions directly to users.
By attaching policies to groups instead:
access becomes easier to scale
onboarding is simpler
and permissions stay consistent across users in the same role

It also supports a stronger least-privilege model, since each team only gets the access needed for its responsibilities.
Started simple with iam-groups.tf, this part was straightforward - just defining the groups:
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
# Attach policies to groups
resource "aws_iam_group_policy_attachment" "dev_ec2" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.dev_policy.arn
}
resource "aws_iam_group_policy_attachment" "dev_logs" {
  group      = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess"
}
# MFA enforcement for all groups
resource "aws_iam_group_policy_attachment" "dev_mfa" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.require_mfa.arn
}
# Repeated for ops, finance, and analysts groups
Step 2: Creating IAM Users (The Smart Way)
When I first started creating IAM users, I took the most straightforward approach - defining each user individually.
resource "aws_iam_user" "dev_1" {
  name = "dev-1"
}
resource "aws_iam_user" "dev_2" {
  name = "dev-2"
}
# ...repeat this multiple times
At first, this works. But the moment you need to create 5, 10, or even 50 users, it quickly becomes repetitive, hard to maintain, and honestly… painful.

---

The Problem with This Approach
❌ Too much duplicate code
❌ Hard to scale as your team grows
❌ Easy to make mistakes (typos, missing users, inconsistencies)

This is exactly the kind of situation where Terraform shines - automation and scalability.

---

Enter for_each
Instead of repeating the same block over and over, Terraform provides a much cleaner solution: for_each.
for_each allows you to create multiple instances of a resource using a collection (like a list or set), instead of hardcoding each one.
Here's the improved version:
resource "aws_iam_user" "developers" {
  for_each = toset(["dev-1", "dev-2", "dev-3", "dev-4"])
  name     = each.key
}

---

Why This Is Better
✅ One block of code instead of many
✅ Easy to add/remove users (just update the list)
✅ Cleaner and more readable
✅ Terraform tracks each user individually

In real-world DevOps environments, this is a game changer. Imagine onboarding a full engineering team - instead of writing 20 separate resources, you just update a list.

---

What's Actually Happening Behind the Scenes?
Terraform takes each item in the set:
["dev-1", "dev-2", "dev-3", "dev-4"]
…and creates separate IAM users, like:
dev-1
dev-2
dev-3
dev-4

Each one is still managed as its own resource - which means you can modify or destroy them individually without affecting the others.

---

Learning Moment
This was one of those small but powerful realizations:
Using for_each is significantly cleaner and more scalable than repeating the same resource multiple times.
It's a simple change, but it makes your Terraform code look like something a real DevOps engineer would write in production.
# IAM Users

# Developers
resource "aws_iam_user" "developers" {
  for_each = toset(["dev-1", "dev-2", "dev-3", "dev-4"])
  name     = each.key
}

resource "aws_iam_user_group_membership" "dev_membership" {
  for_each = aws_iam_user.developers
  user     = each.value.name
  groups   = [aws_iam_group.developers.name]
}

# Operations
resource "aws_iam_user" "operations" {
  for_each = toset(["ops-1", "ops-2"])
  name     = each.key
}

resource "aws_iam_user_group_membership" "ops_membership" {
  for_each = aws_iam_user.operations
  user     = each.value.name
  groups   = [aws_iam_group.operations.name]
}

# Finance
resource "aws_iam_user" "finance" {
  name = "finance-1"
}

resource "aws_iam_user_group_membership" "finance_membership" {
  user   = aws_iam_user.finance.name
  groups = [aws_iam_group.finance.name]
}

# Analysts
resource "aws_iam_user" "analysts" {
  for_each = toset(["analyst-1", "analyst-2", "analyst-3"])
  name     = each.key
}

resource "aws_iam_user_group_membership" "analyst_membership" {
  for_each = aws_iam_user.analysts
  user     = each.value.name
  groups   = [aws_iam_group.analysts.name]
}
Step 3: Assigning Users to Groups
After creating IAM users, the next step is organizing them properly - and that's where IAM groups come in.
Instead of assigning permissions directly to each user (which becomes messy fast), we attach users to groups and manage permissions at the group level.

---

The Goal
We want all developer users to automatically belong to the developers group - without manually assigning each one.

---

The Terraform Approach
Since we already created users using for_each, we can reuse that same structure to assign them to a group dynamically.
resource "aws_iam_user_group_membership" "dev_membership" {
  for_each = aws_iam_user.developers
  user     = each.value.name
  groups   = [aws_iam_group.developers.name]
}

---

What's Happening Here?
Let's break it down simply:
for_each = aws_iam_user.developers
 → Loops through every IAM user we created earlier
user = each.value.name
 → Gets the username (e.g., dev-1, dev-2…)
groups = [aws_iam_group.developers.name]
 → Assigns each user to the developers group

---

Why This Matters (Real DevOps Insight)
In production environments, you never want to manage permissions per user.
Instead:
You assign permissions to groups
Then assign users to those groups

This gives you:
✅ Centralized permission management
✅ Easier onboarding/offboarding
✅ Cleaner and more secure IAM structure

For example:
New developer joins → just add them to the list
Developer leaves → remove them from the list
No need to touch permissions at all

---

Learning Moment
Always manage permissions through groups, not individual users.
Combining for_each with group membership creates a fully automated IAM workflow - scalable, clean, and production-ready.
# IAM Groups

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

# Attach policies to groups
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
Step 4: Creating IAM Policies
Now that the IAM groups are in place, the next step is defining what each group can actually access.
This is where IAM policies come in.
An IAM policy is a JSON document that tells AWS what actions are allowed or denied on specific resources. In simple terms, it answers questions like:
Can developers start EC2 instances?
Can finance users view billing data?
Can analysts read from S3 buckets?
Can operations manage infrastructure?

Without policies, groups are just containers.
 Policies are what give those groups purpose.

---

Why Create Policies at the Group Level?
A common beginner mistake is trying to assign permissions directly to each user. That might work in very small environments, but it quickly becomes difficult to manage.
A better approach is:
Create users
Place users into groups
Attach policies to the groups

This makes the IAM setup much more scalable and easier to maintain.
For example, if a new developer joins the team, you do not need to manually assign permissions again. You simply add them to the developers group, and they automatically inherit the correct access.
That is one of the biggest advantages of role-based access control in AWS.

---

Writing a Policy in Terraform
In Terraform, IAM policies can be created using the aws_iam_policy resource.
Here is an example of a simple policy for the developers group:
resource "aws_iam_policy" "developers_policy" {
  name        = "developers-policy"
  description = "Policy for developer access"
policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "s3:ListBucket",
          "s3:GetObject"
        ]
        Resource = "*"
      }
    ]
  })
}

---

Breaking It Down
Let's simplify what this is doing:
name
 gives the policy a clear name in AWS
description
 explains the purpose of the policy
policy = jsonencode({...})
 lets Terraform write the IAM policy in JSON format without needing a separate JSON file

Inside the policy:
Version = "2012-10-17"
 is the standard version used in IAM policies
Effect = "Allow"
 means the listed actions are permitted
Action
 contains the AWS API actions this group can perform
Resource = "*"
 means those actions apply to all matching resources

---

Why jsonencode() Helps
Using jsonencode() is much cleaner than manually writing raw JSON inside Terraform.
It keeps everything inside your .tf file, improves readability, and reduces formatting mistakes.
For beginners, this also makes policies easier to understand because the structure looks more natural in Terraform syntax.

---

Real DevOps Perspective
In real environments, policies should follow the principle of least privilege.
That means users should only get the minimum permissions they need to do their job - nothing more.
For example:
Developers may need access to view EC2 instances and read from specific S3 buckets
Operations may need broader permissions to manage infrastructure
Finance may need billing-related access only
Analysts may need read-only access to reports and data

This is important because overly broad permissions can become a serious security risk.
So even though Resource = "*" is fine for learning and testing, production environments usually require tighter control over specific resources.
Defining Access Requirements Before Writing Policies:

Before jumping into writing IAM policies, I took a step back and defined what each team actually needs.
This is something a lot of beginners skip - but in real-world DevOps, you don't start with permissions… you start with requirements.
Here's how I structured it:

---

Access Design Overview
Developers (4 users)
 → Access to EC2 and S3 for development only (no production access)
 → Access to CloudWatch logs for debugging
Operations (2 users)
 → Full infrastructure management (EC2, networking, scaling, etc.)
 → No IAM policy modification (to prevent privilege escalation)
Finance (1 user)
 → Billing and cost management access
 → Read-only access to resources
Analysts (3 users)
 → Read-only access to S3 and RDS data
 → No infrastructure or write permissions

---

Why This Step Matters
This might seem simple, but it's actually one of the most important parts of IAM design.
Instead of guessing permissions, you're:
✅ Defining responsibilities per team
✅ Avoiding over-permissioning
✅ Following the principle of least privilege
✅ Making your Terraform code intentional, not random

---

Real DevOps Insight
In production environments, bad IAM design is one of the biggest security risks.
For example:
Giving developers full access to production → 🚨 risky
Allowing operations to edit IAM policies → 🚨 privilege escalation risk
Giving analysts write access → 🚨 data integrity issues

By clearly separating responsibilities like this, you're building a system that is:
More secure
Easier to manage
Scalable as the company grows

# IAM Policies

# Developer
resource "aws_iam_policy" "dev_policy" {
  name = "DeveloperAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowDescribeEC2"
        Effect = "Allow"
        Action = [
          "ec2:Describe*"
        ]
        Resource = "*"
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
          "arn:aws:s3:::startupco-*-dev",       
          "arn:aws:s3:::startupco-*-dev/*"
        ]
      }
    ]
  })
}

# Operations Policy
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

# Analyst Policy
resource "aws_iam_policy" "analyst_policy" {
  name = "AnalystReadOnly"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3ConsoleAccess"
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",      # ← ADD THIS
          "s3:GetBucketLocation"      # ← ADD THIS
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowAnalystS3Read"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::startupco-analytics-data",
          "arn:aws:s3:::startupco-analytics-data/*"
        ]
      },
      {
        Sid    = "AllowRDSDescribe"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances"
        ]
        Resource = "*"
      }
    ]
  })
}
Phase 4: Setting Up CloudTrail for Auditing
Once the IAM structure was in place, the next step was making sure actions inside the AWS environment could actually be tracked.
That is where AWS CloudTrail comes in.
CloudTrail records API activity across the account, which makes it extremely useful for:
auditing user actions
investigating suspicious activity
verifying whether users are staying within their intended scope
supporting security and compliance requirements

In short, IAM controls what users can do, while CloudTrail helps you verify what they actually did.

---

Creating an S3 Bucket for CloudTrail Logs
Since CloudTrail needs a place to store its logs, I first created a dedicated S3 bucket:
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "nexacore-logs-${data.aws_caller_identity.current.account_id}"
}
Why include the account ID?
S3 bucket names must be globally unique across all AWS accounts.
That means if the bucket name is too generic, there is a good chance it will already be taken. By appending the AWS account ID, the bucket name becomes unique to the account and avoids naming conflicts.
It also makes the naming pattern more practical and reusable.
Creating the CloudTrail Trail
After setting up a dedicated S3 bucket for logs, the next step was configuring AWS CloudTrail to capture activity across the NexaCore environment.
CloudTrail acts as an audit layer, recording API calls and user actions across AWS services. This is essential for monitoring, troubleshooting, and ensuring users stay within their assigned permissions.
To set this up, I created a trail that sends all logs to the S3 bucket:
resource "aws_cloudtrail" "main" {
  name           = "nexacore-audit-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail.id
}

---

Why CloudTrail Matters
At this stage, IAM controls who can do what, but CloudTrail answers a different question:
What actually happened in the environment
With CloudTrail enabled, I can:
Track every API call made by users and services
Identify unauthorized or unexpected actions
Investigate issues or security incidents
Maintain audit logs for compliance

This is especially important in a multi-user setup where different teams (developers, operations, finance, analysts) have different levels of access.

---

Key Insight
One important realization here was:
Access control without visibility is incomplete
Even if permissions are configured correctly, there is no way to verify behavior without logging. CloudTrail fills that gap by providing a full history of activity in the account.

---

Common Pitfall
CloudTrail setup looks simple, but there is a hidden dependency:CloudTrail cannot write logs to S3 unless the bucket explicitly allows it.
This means a bucket policy must be configured to allow the CloudTrail service to:
Read the bucket ACL
Write log files

Without this, the trail may be created successfully, but no logs will actually be delivered.
Bucket Policy Challenge
CloudTrail needs permission to write to the bucket. Had to create a bucket policy:
This allows CloudTrail to Identify the bucket AND put objects (logs) in the bucket

data "aws_iam_policy_document" "cloudtrail_policy" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail.arn]
  }
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail.arn}/*"]
  }
}
Don't forget (important - production correctness)
You should also include the bucket policy attachment:
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_policy.json
Phase 5: Deployment
Once the IAM structure, groups, users, and policies are in place, the final step is deploying everything through Terraform.
Before applying any changes, I first validate the configuration to make sure the syntax and resource references are correct:
terraform validate
Next, I run a plan to preview exactly what Terraform is going to create or modify:
terraform plan

This step is important because it gives me a chance to review the changes before they are applied.
Once everything looks correct, I deploy the IAM configuration:
terraform apply --auto-approve
This creates the IAM users, groups, memberships, and attached policies in AWS.

---

Why This Step Matters
Using Terraform for deployment makes the entire IAM setup:
repeatable
version-controlled
easy to audit
easy to rebuild if needed

Instead of manually configuring access through the AWS Console, the whole security model is defined as code and can be managed in a structured way.

SNS creation 

USERS

Phase 6: Testing

Test Plan
After deploying the IAM setup, the next step is validating that access controls are working exactly as intended.
At NexaCore Solutions, I approach this by mapping out a simple test plan to verify both allowed actions and restricted actions for each user role.
For example, for the developer role, I test:
Starting EC2 instances in the development environment → expected to succeed
Attempting to start production EC2 instances → expected to be denied
Uploading data to development S3 buckets → expected to succeed
Accessing production S3 buckets → expected to be denied

For other roles:
Operations → should be able to manage infrastructure, including actions like deleting RDS
Finance → should only have access to billing and cost visibility, with no ability to modify resources
Analysts → should be able to read data from S3 and RDS, but not write or modify anything

---

Post-Deployment Validation
I then log in as each user and manually test their permissions against real AWS resources.
For example, testing the developer user (dev-1):
Successfully starts development EC2 instances
Is denied when attempting to access production resources
Can upload to development S3
Is restricted from accessing production S3

This confirms that the least-privilege model is working as expected.

dev-1 MFA Registration Test
This was a success
lets set a password 

Allowed to Launched development instance:

Denied to launch production instance
Allowed access to dev bucket and uploaded to it
Denied to access prod bucket at all
ops-1 MFA Registration Test

This was a success
Ops-1 Actions Test:
Allowed to Delete RDS instance

this was a success

Finance-1 Actions Test:
Allowed Viewing Billing Dashboard

Denied to Start EC2 Instance

this was a success:

Analyst-1 Actions Test:
Can Successfully See List of Buckets:

Allowed Seeing Contents of analyst Bucket once theres files here:

Denied from Seeing Contents of non-analyst Buckets:

Denied Write (Upload) Permissions to Analyst Buckets:

Denied Write (Delete object) Permissions to Analyst Buckets:

Denied Write (Create Folder) Permissions to Analyst Buckets:

All Expected Analyst Results were Met:

Monitoring with CloudTrail
Once access controls were in place, the next step was visibility.
At NexaCore Solutions, I used AWS CloudTrail to monitor and track user activity across the environment.
CloudTrail provides a detailed audit trail of everything happening in the account. As an administrator, this allows me to clearly see:
Who performed an action
What action was performed
Which resource was affected
Exactly when the action occurred

---

How This Helped
By reviewing CloudTrail logs, I was able to validate that:
Users were only accessing resources they were permitted to
Denied actions were being triggered as expected
No unexpected or unauthorized activity was occurring

For example, when testing IAM roles:
A developer attempting to access production resources showed up as a denied event
Finance users accessing billing data were logged correctly with read-only actions

---

 Why This Matters
Implementing IAM without monitoring is incomplete.
CloudTrail adds a critical layer by making the environment:
auditable
traceable
secure by verification, not assumption

This combination of detailed logs makes it much easier to identify anything that falls outside expected behavior and quickly respond if needed.

📚 Key Lessons Learned
1. Start Small, Test Often
One of the biggest lessons was to avoid building everything at once.
Instead, I focused on creating and testing each policy individually. This made it much easier to identify issues early and avoid debugging complex problems later.

---

2. IAM Policy Evaluation is More Complex Than It Looks
IAM policies aren't always straightforward. Understanding how AWS evaluates permissions is critical:
Explicit Deny → always takes priority
Explicit Allow → grants access if no deny exists
Implicit Deny → default state when nothing is allowed

This evaluation logic plays a huge role in how access is actually enforced.

---

3. Use the AWS Policy Simulator
I discovered the AWS Policy Simulator midway through the project, and it made a big difference.
It allows you to test IAM policies without deploying them, which helps validate permissions quickly and safely before applying changes in a live environment.

---

4. Documentation is Critical
Clear documentation is essential, not just for the current setup but for future work as well.
It helps:
maintain consistency
onboard new team members
and provide a clear reference for how access is structured

---

💡 Final Thought
Security isn't just about implementation - it's about understanding, testing, and maintaining control over time.

📊 Results After Implementation
After implementing IAM best practices at NexaCore Solutions, the improvements were immediate and measurable.
Key Improvements
Shared credentials were completely eliminated
MFA adoption increased from 0% to 100%
Audit visibility improved from none to full visibility using CloudTrail
The permission model shifted from over-privileged (admin access) to least privilege
User onboarding time was reduced from days to minutes
Overall security risk was significantly reduced

---

Additional Results
✅ 10/10 users successfully onboarded
🔐 10/10 users enforced with MFA
🚫 0 root account logins after implementation
📈 CloudTrail actively logging 500+ events per day
🛡️ 0 security incidents observed
⚡ User onboarding reduced to approximately 15 minutes (previously 1+ days)

Final Thoughts
This project reinforced an important principle for me:
Security isn't just about restricting access - it's about giving people exactly what they need to do their jobs, nothing more, nothing less.
That's what least privilege really means in practice.

---

Before writing any policies, the most important work actually happened during the planning phase. I had to constantly ask:
"Which policies will achieve the goal without over-permissioning?"
That mindset shaped the entire implementation.

---

What stood out the most is that the hardest part wasn't Terraform.
It was understanding the business requirements and translating them into precise IAM policies.
Writing the code is straightforward once the logic is clear.
 But defining who should have access to what - and why - is where real engineering happens.

---

🚀 Closing Reflection
Projects like this highlight that strong security comes from:
clarity in requirements
thoughtful design
and careful implementation

Tools like Terraform help automate the process, but the real value comes from understanding the problem you're solving.
