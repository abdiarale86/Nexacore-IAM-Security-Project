
Nexacore IAM Security Project
Terraform AWS IAM CloudTrail

Implemented secure IAM infrastructure for a startup that was sharing AWS root account credentials. This project established proper role-based access control (RBAC) and eliminated critical security vulnerabilities.

## 🏗️ Architecture

![Architecture Diagram](screenshots/architecture-diagram.svg)

**Model:** Shared root account (retired) → individual IAM users, all MFA-enforced under an account-wide password policy → grouped into Developers, Operations, Finance, and Data Analysts, each scoped to a least-privilege policy for their role.

See [DOCUMENTATION.md](DOCUMENTATION.md) for the full implementation walkthrough.

🚨 View Documentation on Medium to see full journey of the project 🚨
https://medium.com/@a.arale86/implementation-guide-nexacore-solutions-iam-security-project-64842b02ce50
