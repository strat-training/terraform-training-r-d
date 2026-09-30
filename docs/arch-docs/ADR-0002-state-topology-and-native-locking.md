# ADR-0002: State topology — persistent bootstrap root + ephemeral capstone roots, S3 native locking

- **Status:** Accepted; amended 2026-09-29 (bootstrap also holds the CI identity)
- **Date:** 2026-09-28
- **Modules affected:** M2 (backend), M11 (workspaces), M13 (budget), M14–M16, M17
- **Related:** ADR-0003, ADR-0009, ADR-0011, ADR-0012

## Context

M2 requires remote state in S3 with native locking and no DynamoDB table. Two problems follow:

1. **Chicken-and-egg:** the backend bucket cannot be created by the configuration that uses it as its backend.
2. **Teardown vs. persistence:** learners run `terraform destroy` at the end of every session (ADR-0003). Destroying the state bucket, or the account-wide budget, every session would break the next session's `init` and remove cost protection.

Native S3 locking (`use_lockfile`) was introduced experimentally in Terraform 1.10 and became generally available in 1.11. HashiCorp's docs mark DynamoDB-based locking as deprecated.

## Decision

1. Two kinds of root:
   - **`bootstrap/`** — *persistent*. Local state. Creates the state bucket and the account-wide AWS Budget (M13 module instantiated here). **Never** part of session teardown.
   - **`capstone/aws/`** and **`capstone/multicloud/`** — *ephemeral*. S3 backend, destroyed every session.
2. Backend config: `use_lockfile = true`, `encrypt = true`, region `ap-southeast-1`, **no `dynamodb_table`**. Pin `required_version = ">= 1.11.0"` in every root (GA locking; avoids learners on 1.10 hitting the experimental path).
3. State bucket: versioning on, SSE enabled, all public access blocked, `prevent_destroy = true`, and a lifecycle rule **expiring noncurrent versions after 7 days**. Reason: with versioning on, every lock create/delete leaves a tiny noncurrent version; the rule stops that from accumulating.
4. State keys: `capstone/aws/terraform.tfstate` and `capstone/multicloud/terraform.tfstate`. With workspaces (M11) the S3 backend stores non-default workspaces under an `env:/<workspace>/` prefix automatically.
5. IAM for learners on the bucket: `s3:ListBucket` on the bucket, and `s3:GetObject`/`PutObject`/`DeleteObject` on the state key prefix (delete is required because the lock file is removed after each operation).
6. Bootstrap's local state file is git-ignored. If lost, the bucket is recovered with `terraform import`; the runbook documents this.

## Options considered

| Option | Verdict |
|---|---|
| Local state only | Rejected — fails M2's objective. |
| S3 + DynamoDB lock table | Rejected — deprecated locking path, extra resource and cost, and contradicts the PRD. |
| HCP Terraform / other hosted backend | Rejected — external service outside the sandbox scope. |
| Create the bucket by hand in the console | Rejected — undocumented, not reproducible; bootstrap root is equally cheap and teaches the pattern. |
| **Bootstrap root (local state) + S3 backend for the rest** | **Chosen** |

## Consequences

- One extra root for learners to understand, but it is written once in M2 and rarely touched.
- The budget survives teardown, so cost protection is continuous.
- State-bucket cost is negligible (a few KB of objects); confirm the lifecycle rule is applied so versioning does not grow.
- Losing bootstrap state is inconvenient but recoverable.

## Verify before publishing

Confirm the minimum Terraform version against the current backend docs before pinning in course material.

## Amendment — 2026-09-29: CI identity in `bootstrap/`

`bootstrap/` also owns the GitLab CI identity (`bootstrap/ci.tf`, ADR-0011): an IAM OIDC provider for `https://gitlab.com`, and a read-only `plan` role, created only when `var.gitlab_project_path` is set. Like the state bucket and the budget, it must survive between sessions, so it belongs in the persistent root. Nothing in the course is created outside a Terraform root (ADR-0012).

## Amendment — 2026-09-29 (later): CI identity removed

With CI/CD out of scope ([ADR-0013](ADR-0013-cicd-out-of-scope.md)), `bootstrap/ci.tf` is removed. `bootstrap/` holds only the state bucket (`main.tf`) and the budget (`budget.tf`).
