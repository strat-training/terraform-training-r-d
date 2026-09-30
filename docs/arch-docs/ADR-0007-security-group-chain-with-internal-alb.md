# ADR-0007: Security-group chain including the internal ALB hop

- **Status:** Accepted; amended 2026-09-29 (the M9 hardening step is adopted)
- **Date:** 2026-09-28
- **Modules affected:** M4, M7, M9, M10
- **Related:** ADR-0004, ADR-0006, soldoc gaps G3, G13

## Context

M7 defines the zero-trust chain `Web-SG (0.0.0.0/0) → App-SG (from Web-SG only) → DB-SG (from App-SG only)`. M9's challenge then places an **internal ALB** between Web and App. Traffic reaching App instances now originates from the ALB's network interfaces, not from Web-SG members, so a rule allowing App-SG "strictly from Web-SG" would stop working. M4's tier map also describes sources as IPs, whereas M7 needs security-group references.

## Decision

Final chain (each arrow = an ingress rule whose *source* is the previous group, never a CIDR except at the internet edge):

| Group | Ingress | Egress |
|---|---|---|
| `WebALB-SG` | 80 ← `0.0.0.0/0` | 80 → `Web-SG` |
| `Web-SG` | M7 as written: 80/443 ← `0.0.0.0/0`. **Proposed hardening at M9:** 80 ← `WebALB-SG` only | 8080 → `AppALB-SG`; 80/443 → internet (bootstrap, via IGW) |
| `AppALB-SG` | 8080 ← `Web-SG` | 8080 → `App-SG` |
| `App-SG` | 8080 ← `AppALB-SG` | 3306 → `DB-SG`; 80/443 → internet via NAT; S3 via gateway endpoint |
| `DB-SG` | 3306 ← `App-SG` | **No internet egress** (M7 challenge); traffic back to `App-SG` only |

1. The M4 tier map (`web`, `app`, `db` → ports and sources) remains the **single source of truth**: its `sources` field accepts CIDRs (the Web edge) or tier names (App, DB), which are resolved to security-group IDs. Security groups are generated from it with `for_each`/`dynamic` blocks.
2. Use **one style consistently** for rules (inline `dynamic` blocks as taught in M4, or standalone rule resources), never mixed on the same group.
3. App listens on **8080** and exposes **`/health`**, matching the M9 health check.
4. NACLs stay at defaults and are covered in lecture only (per M7).
5. Remember statefulness: return traffic is allowed automatically; the DB-SG egress rule is defence-in-depth and a teaching point, not what makes replies work.

## Options considered

| Option | Verdict |
|---|---|
| Keep `App-SG ← Web-SG` and let the ALB share Web-SG | Rejected — mixes tiers, defeats least privilege. |
| Allow `App-SG` from the Web subnet CIDRs | Rejected — CIDR trust instead of identity; breaks the zero-trust message. |
| Add `AppALB-SG` hop | **Chosen** |
| Tighten Web-SG to the ALB only | **Proposed** — free and strictly better, but departs from M7's explicit text; adopt in the M9 guided activity if the PRD owner agrees. |

## Consequences

- Two extra security groups (free) and one more rule pair to explain; the chain is easy to draw and to test with the checkpoint's expected results.
- If the Web-SG hardening is adopted, Web instances hold public IPs (needed for outbound bootstrap through the IGW) but are unreachable directly from the internet.

## Amendment — 2026-09-29: M9 hardening adopted

The step marked **Proposed** (Web-SG accepts 80 only from `WebALB-SG`, not from `0.0.0.0/0`) is **adopted** in the course, as the M9 planned refactor. The only `0.0.0.0/0` ingress left in the final stack is on `WebALB-SG`.

Implementation notes from the validated reference solution:
- The chain is expressed as one `tier_rules` map (`web_alb`, `web`, `app_alb`, `app`, `db`) and expanded with `setproduct`.
- Rules are **standalone** `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` resources. Inline rules between groups that reference each other would form a dependency cycle.
- Each group-to-group ingress gets a mirrored egress rule on the source group.
- `DB-SG` has **no** egress rules at all. Replies to the App tier flow because security groups are stateful.

