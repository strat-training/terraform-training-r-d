# Coding Standards — Terraform samples in this course

Every HCL, shell and YAML sample that appears in `modules/*.md` or
`capstone/*.md` follows these rules. A sample that breaks one is a bug in
the course. Sources: [Terraform style guide](https://developer.hashicorp.com/terraform/language/style),
soldoc §6–§7, ADR-0002 to ADR-0010.

## Versions
- Root modules: `required_version = ">= 1.11.0"` and **exact** provider
  versions from `knowledge/references/terraform-bootcamp-sources.md`
  (`aws 6.66.0`, `random 3.9.1`, `google 8.4.0`, `azurerm 5.7.0`).
- Child modules: minimum constraints only (`>= 6.0`), never exact pins.
- Never write versions from memory. Re-resolve with `resolve_package_versions`
  before a new cohort, then update this file and the sources file together.
- Commit `.terraform.lock.hcl`.

## Layout and naming
- Files per root: `versions.tf`, `providers.tf`, `variables.tf`, `main.tf`,
  `outputs.tf`. Modules add files by concern (`iam.tf`, `security_groups.tf`).
- Resource names: `${var.project}-${terraform.workspace}-<role>`
  (`name_prefix` local). Terraform labels: `snake_case`, no type repeated in
  the label (`aws_lb.web`, not `aws_lb.web_lb`).
- Every variable has a `type`; every non-obvious variable has a `description`.
- `for_each` over maps is the default. Use `count` only for on/off toggles
  (`count = var.x ? 1 : 0`).

## Tagging
- Provider `default_tags`: `Project`, `Env`, `Teardown`, `ManagedBy`.
  Add `Name` per resource. GCP uses `default_labels` (lowercase keys) and Azure
  uses explicit `tags`.

## Security
- No plaintext secret in any `.tf`, `.tfvars`, script or doc sample.
  Passwords come from `random_password` → Secrets Manager (or
  `manage_master_user_password`). The lecture states that `random_password`
  still lands in state, so state must be encrypted and private.
- No `0.0.0.0/0` **ingress** except the Web ALB edge, with a justification
  comment on the line. Internet **egress** CIDRs also carry a comment.
- Security-group sources between tiers are group references, never CIDRs.
  Use one rule style per group: inline `dynamic` (M4 prototype) or standalone
  `aws_vpc_security_group_*_rule` resources (M7 onward). Never mix them on the
  same group.
- IAM: build policies with `aws_iam_policy_document`. Scope resources to exact ARNs, with no
  `"*"` in our own policies. AWS-managed policies are the only exception and
  carry a comment.
- IMDSv2 required on every Launch Template (`http_tokens = "required"`).
- State: S3 backend, `encrypt = true`, `use_lockfile = true`, no
  `dynamodb_table`. The bucket name comes from `backend.hcl` (git-ignored), never
  hardcoded with an account ID.

## Cost guardrails (non-negotiable in samples)
- `credit_specification { cpu_credits = "standard" }` on every T3 instance or
  Launch Template.
- `force_destroy = true` on lab buckets. On RDS: `skip_final_snapshot = true` and
  `backup_retention_period = 0`. On lab secrets: `recovery_window_in_days = 0`.
- NAT behind `nat_gateway_enabled`. RDS `multi_az = false`, engine `8.4`, never
  `8.0`.
- Every lab states its apply window, estimated cost, what is left off, and ends
  with `terraform destroy`, then `terraform state list` printing nothing.
- Every cloud resource a lab needs is a Terraform resource. No console click-ops. Data files copied into
  buckets are fine only when the bucket has `force_destroy`.

## Modules
- One child module per resource type, named after what it creates (`alb`, `asg`,
  `rds-mysql`, …). `network` is the one grouped module (VPC, subnets, routes change
  together). Each module: variables, resources, outputs in `main.tf`; minimum
  provider constraint only.
- The root wires modules together and owns cross-cutting resources (SSM
  `runtime_config`, the dashboard, IAM policy statements).

## Commands
- Commands shown to trainees go in fenced blocks (see
  `knowledge/patterns/module-content-structure.md`).
- `terraform plan` before every `apply`, always.
- CI/CD pipelines are out of scope for this bootcamp (ADR-0013).

## Verification before publishing a sample
- `terraform fmt -check -recursive`, then `terraform init -backend=false`
  and `terraform validate` against the pinned providers.
- Run `terraform test` (mocked providers) for validation rules and guards.
- Run `bash -n` on every rendered user-data or helper script.
- Run Checkov (`checkov -d <reference> --framework terraform --compact`) on the assembled
  reference solution. Every failure must be either fixed or listed as accepted-by-design
  in the latest `knowledge/retros/*-validate.md`. When refactoring modules, re-check
  that the cost/security settings survive: encrypted gp3 root volumes, IMDSv2, standard
  CPU credits, and a `description` on every security-group rule.
- Check every HCL block in `modules/*.md` against the validated reference (the drift
  check): module code must match verbatim; only earlier-stage examples may differ.
- Keep EC2 user data under 16 KB after `templatefile()` rendering, and avoid `${`
  and `%{` in embedded JavaScript/shell (use `$${` when you really need a literal).
