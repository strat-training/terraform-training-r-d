# ADR-0004: Egress — one NAT Gateway, feature-flagged

- **Status:** Accepted (default). NAT-instance variant recorded as an optional stretch, not adopted.
- **Date:** 2026-09-28
- **Modules affected:** M6 (introduces), M7, M8, M11
- **Related:** ADR-0003, ADR-0007

## Context

The PRD mandates a **single NAT Gateway, never two, even in `prod`**. NAT Gateway is the largest fixed hourly cost in the stack: an hourly charge that applies whenever it exists, a per-GB processing charge, and an additional $0.005/h for its Elastic IP (AWS charges every public IPv4 address hourly). Asia-Pacific hourly rates are higher than US East (AWS lists Sydney at $0.059/h). Private App instances need outbound access to bootstrap packages and reach SSM and Secrets Manager.

## Decision

1. Exactly **one standard NAT Gateway** in public subnet A (`ap-southeast-1a`).
2. Route tables (M6's three tables): Web RT → IGW; **App RT → NAT** (default route); **DB RT → local only, no default route**. RDS never needs the internet, and this pre-empts the M7 challenge (DB egress lock-down).
3. A module variable **`nat_gateway_enabled`** controls creation of the NAT Gateway, its EIP and the App RT default route.
   - `true` for M6's checkpoint and every module that runs App instances (M8–M13, final run).
   - `false` for modules that only need network/IAM/SGs (M7), and for any plan-only work.
   - A `precondition` fails the plan if App ASG capacity > 0 while NAT is disabled (instances would hang on bootstrap).
4. Add a **free S3 gateway VPC endpoint** attached to the App and DB route tables so S3 traffic (uploads bucket) never crosses NAT or incurs NAT per-GB processing.
5. The same one-NAT topology is used in every workspace (ADR-0008); only one workspace is live at a time.

## Options considered

| Option | Verdict |
|---|---|
| NAT Gateway per AZ | Rejected — PRD forbids; doubles cost. |
| NAT Gateway always on across sessions | Rejected — ≈ $1.5/day on its own. |
| **One NAT Gateway, created only in windows that need it** | **Chosen** |
| NAT instance (e.g. a community NAT AMI on a nano instance) | Cheaper (a `t3.nano` is roughly a tenth of NAT Gateway hourly cost), but needs source/dest-check disabled, its own SG, patching and a manual failure story, and departs from the M6 lecture. Kept as an *optional* stretch exercise only. |
| Interface VPC endpoints (SSM, Secrets Manager) instead of NAT | Rejected — each interface endpoint bills hourly per AZ, and package bootstrap (apt) still needs internet. |
| IPv6 egress-only gateway | Rejected — out of scope and not part of the PRD topology. |

## Consequences

- Single-AZ egress: if AZ `a` fails, all private outbound stops. Accepted by the PRD's cost-trimmed topology and taught in the lecture as a trade-off.
- M7 costs $0 because NAT and instances are off.
- Learners must remember `nat_gateway_enabled = true` when moving on to M8; the precondition gives a clear error if they forget.

## Verify before publishing

Check the Singapore NAT and public IPv4 rates in the AWS Pricing Calculator; the ledger uses a rounded planning figure of $0.064/h (NAT + EIP).
