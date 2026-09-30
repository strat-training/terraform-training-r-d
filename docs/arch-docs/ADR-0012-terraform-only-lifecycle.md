# ADR-0012: Terraform-only lifecycle — no teardown script; `terraform destroy` is the teardown

- **Status:** Accepted
- **Date:** 2026-09-29
- **Supersedes:** ADR-0003 decision 7 (`scripts/teardown-check.sh`), and the teardown-script parts of soldoc §6, §7.4 and §8
- **Modules affected:** all (M1–M17), the capstone (requirement 18)
- **Related:** ADR-0002, ADR-0003, ADR-0011

## Context

ADR-0003 added `scripts/teardown-check.sh`: AWS/GCP/Azure CLI queries that list leftover NAT Gateways, load balancers, RDS instances, EC2 instances, unattached EIPs, GCS buckets and Azure resource groups. It was a second line of defence against a forgotten stack.

The course owner decided that the course should not need it. **Every resource is managed by Terraform, so `terraform apply` and `terraform destroy` are the whole lifecycle.** A script that re-discovers resources with cloud CLIs duplicates Terraform's own state. It also teaches the wrong lesson: that Terraform might not know what it created.

The only place the course broke this assumption was M17, where the CI OIDC provider and role were created by hand in the console. That is now Terraform-managed (ADR-0011).

## Decision

1. **No teardown script.** Remove `scripts/teardown-check.sh` from the repository layout, the labs and the capstone.
2. **Teardown is Terraform.** Every session ends with `terraform destroy` in each root and workspace that was applied: `capstone/multicloud` first, then `capstone/aws`, never `bootstrap/`.
3. **Proof of teardown is an empty state.** `terraform state list` prints nothing in each destroyed root. This is the checkpoint in every lab, and the evidence for capstone requirement 18.
4. **Golden rule: nothing is created by hand.** No console click-ops for any cloud resource, including CI identities (ADR-0011). If something was created by hand, it must be imported into Terraform or deleted. It must never be left outside state.
5. **Data is not infrastructure.** Files copied into Terraform-managed buckets (the seed SQL and the dump in the uploads bucket, the dump in the GCS bucket) are allowed, because those buckets set `force_destroy = true` and `terraform destroy` removes them with the bucket.
6. **Tags stay** (`Project`, `Env`, `Teardown`, `ManagedBy`, ADR-0003 decision 6) for attribution in the console and billing views. They are no longer read by any script.
7. **The safety net is unchanged:** the account-wide budget alerts at 40%, 80% and 100% forecast (ADR-0003 decision 8), which live in `bootstrap/`.

## Options considered

| Option | Verdict |
|---|---|
| Keep `teardown-check.sh` (ADR-0003 §7) | Rejected — duplicates Terraform state with CLI queries across three clouds; extra tooling for trainees; course owner decision. |
| Automated reaper (Lambda) | Rejected earlier in ADR-0003 and still rejected. |
| `terraform plan -destroy` as the check | Not adopted — `state list` after destroy is simpler, and a direct proof that nothing is tracked. |

## Consequences

- One less tool for trainees, and one consistent mental model: Terraform created it, so Terraform removes it.
- The guarantee is only as good as the golden rule. A resource created by hand in a console is invisible to both `destroy` and `state list`. Budget alerts remain the backstop, and facilitators ask about console changes in the capstone defense.
- A resource that fails to delete (a dependency violation, or a provider timeout) stays in state, so `state list` shows it. Re-running `terraform destroy` is the fix.
