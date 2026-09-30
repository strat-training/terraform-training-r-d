# ADR-0003: Cost guardrails — ephemeral apply windows and teardown discipline

- **Status:** Accepted; decision 7 superseded by [ADR-0012](ADR-0012-terraform-only-lifecycle.md) (2026-09-29)
- **Date:** 2026-09-28
- **Modules affected:** all; especially M6–M13
- **Related:** soldoc §7, ADR-0004, ADR-0005

## Context

The PRD caps each learner at **< $5 combined across AWS, GCP and Azure**. The full 3-tier stack (NAT Gateway, two ALBs, RDS, four EC2 instances, public IPv4 addresses) costs roughly **$0.23/hour ≈ $5.50/day** at planning rates. A single forgotten overnight session would exceed the entire budget. Cost control therefore has to be a property of how the course is run, not just of which instance sizes are chosen.

## Decision

1. **Apply windows.** Every module states an *apply → checkpoint → destroy* window and the estimated cost (soldoc §7.3). Nothing billable outlives a session.
2. **Plan first, apply late.** `terraform plan` is free and is the default check. Each module applies only the layers its checkpoint needs and lists what is deliberately **left off** (for example, M7 needs no NAT and no instances; M11 verifies prod by plan only).
3. **Free-first validation.** Where useful, `terraform validate` and `terraform test` with mocked providers (Terraform ≥ 1.11) check validation rules (M2), dynamic blocks (M4), and workspace ternaries (M11) at $0 before any apply.
4. **Instance settings that avoid hidden charges:** `t3.micro`; `credit_specification { cpu_credits = "standard" }` (T3 defaults to *unlimited* credits, which can bill surplus); detailed monitoring off; small gp3 root volumes; dev ASGs at min 1.
5. **Observability within free allowances:** at most 3 CloudWatch dashboards and 10 alarms, no custom metrics, no log exports. (Confirm current free-tier allowances before publishing.)
6. **Attribution:** all resources named `${project}-${terraform.workspace}-<role>` and tagged via provider `default_tags` (`Project`, `Env`, `Module`, `Teardown=every-session`). Tags are for attribution in the console and billing views (originally also read by the teardown script, removed by ADR-0012); tag-filtered budgets remain out of scope per the PRD.
7. ~~**Teardown verification:**~~ *(Superseded by ADR-0012: teardown is `terraform destroy`, proven by an empty `terraform state list`; no script.)* `scripts/teardown-check.sh` lists any remaining NAT Gateway, load balancer, RDS instance, running EC2 instance, or unattached EIP in `ap-southeast-1`, plus GCS buckets and Azure resource groups belonging to the project. Learners must see empty output before ending a session.
8. **Budget alerts** (account-wide, from the bootstrap root): 40% ($2) and 80% ($4) on actual spend, plus a forecast alert at 100% (M13 challenge). Alerts are a stop signal, not a control.
9. **Destroy-friendly resources:** `force_destroy = true` on lab buckets, `skip_final_snapshot = true` on RDS, `recovery_window_in_days = 0` on the Secrets Manager secret so a re-apply is never blocked by a pending-deletion name.

## Options considered

| Option | Verdict |
|---|---|
| Rely on the free tier or promotional credits | Rejected — not guaranteed in sandboxes; the PRD's $5 is the planning constraint. |
| Automated reaper (EventBridge + Lambda) destroying tagged resources | Rejected — new resources, IAM and code to write and pay for; not in PRD scope; a manual check is cheaper and teaches the habit. |
| Scheduled ASG scale-to-zero overnight | Rejected — does not remove NAT, ALBs or RDS, which are most of the cost. |
| Local emulator (e.g. mock cloud) instead of real AWS | Rejected as the primary path — the PRD teaches real AWS; mocked `terraform test` is kept as a supplement only. |
| Keep the stack up between sessions for convenience | Rejected — ≈ $5.50/day. |

## Consequences

- Learners re-create the stack each session, so the code must be reliably idempotent and fast to apply; this is also good IaC practice.
- The 2× rework buffer in the ledger assumes learners use `plan` and mocked tests before repeating long M8–M10 applies.
- Estimates depend on planning rates that must be re-verified each cohort.
