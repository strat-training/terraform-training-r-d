# ADR-0008: Environments via workspaces; prod is plan-only by default

- **Status:** Accepted
- **Date:** 2026-09-28
- **Modules affected:** M2, M11, and every module that sizes resources
- **Related:** ADR-0002, ADR-0003, ADR-0004, ADR-0005, soldoc gap G5

## Context

M11 uses `terraform workspace` for `dev` and `prod`, with sizes driven by `terraform.workspace`. The PRD says both share "the same single NAT Gateway topology" and single-AZ RDS. Separate workspaces have separate state and therefore separate VPCs, so two applied workspaces would mean two NAT Gateways and two RDS instances — contradicting "never two" and doubling cost.

## Decision

1. Two workspaces only: **`dev`** (default working environment) and **`prod`**. A `precondition` rejects the built-in `default` workspace and anything else, tying M2's `var.environment` validation (`dev|staging|prod`) to the workspace name.
2. One `locals` sizing map keyed by workspace:

   | Setting | dev | prod |
   |---|---|---|
   | Web ASG min–max | 1–2 | 2–4 |
   | App ASG min–max | 1–2 | 2–4 (M8 PRD range) |
   | RDS class / storage | micro / 20 GB | next class up / larger volume (M11 challenge) |
   | NAT Gateways | 1 | 1 |
   | Multi-AZ | no | no |

3. **Interpretation of "share the same NAT topology":** each workspace's stack contains *exactly one* NAT Gateway and single-AZ RDS. **Only one workspace is applied at a time.**
4. **`prod` is verified by `terraform plan` only** in M11. The single time `prod` is applied is the **integrated final run** (≤ 1.5 h), which is also the only place prod-sized RDS is created; its cost (≈ $0.39) is in the ledger.
5. Resource names embed the workspace so an accidentally left-behind resource is attributable (ADR-0003).
6. `terraform workspace select dev` is step 1 of every session protocol; the shell prompt or teardown script prints the active workspace.

## Options considered

| Option | Verdict |
|---|---|
| Directory-per-environment | Rejected — PRD's M11 is explicitly about workspaces. |
| Apply dev and prod side by side | Rejected — two NAT Gateways and two RDS instances contradict the topology and the budget. |
| **Workspaces with prod plan-only** | **Chosen** |

## Consequences

- Learners still see prod's sizing logic and plan output without paying for it.
- A prod-only bug can survive until the final run; the mitigation is a full `plan` against prod during M11 plus `terraform test` on the sizing map.
- Workspace state lives at `env:/<workspace>/…` in the state bucket (ADR-0002).
