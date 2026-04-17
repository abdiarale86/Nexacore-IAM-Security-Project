# IAM Policies
# MFA Requirement Policy
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

# No Custom Finance policy because AWS managed policies were sufficient enough
# View iam-groups.tf to see policies used for Finance user


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
          "arn:aws:s3:::nexacore-*-dev/*",
          "arn:aws:s3:::nexacore-logs-319556312800",
          "arn:aws:s3:::nexacore-logs-319556312800/*"
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
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation"
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
          "arn:aws:s3:::nexacore-analytics-data",
          "arn:aws:s3:::nexacore-analytics-data/*"
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