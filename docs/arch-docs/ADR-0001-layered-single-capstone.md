# ADR-0001: Layered single-capstone architecture and module-to-layer mapping

- **Status:** Accepted
- **Date:** 2026-09-28
- **Modules affected:** all (M1–M17)
- **Related:** soldoc §2–§4

## Context

The PRD requires a "Unified Progressive Capstone": every week builds toward or extends one 3-tier AWS system, ending with a multi-cloud backup and asset tier. Modules are written as 17 independent lessons, so without a rule about *how they stack*, learners face refactors, circular references, and reference solutions that drift apart.

## Decision

1. Treat the curriculum as **ten layers (L0–L9)**. A layer may depend on layers below it and never on layers above it (soldoc §2).
2. Keep **one evolving codebase**: prototype phase (M1–M5) lives in `capstone/aws/` against the default VPC; M5 extracts `modules/compute` and `modules/storage`; M6 introduces the custom VPC; later modules add modules, not new roots (the only additional root is `capstone/multicloud/`, ADR-0009).
3. Allow exactly three planned refactors of earlier work, all named in the module text so learners expect them:
   - **M6** replaces the default VPC with the custom VPC.
   - **M7** rewires security groups from CIDR sources to security-group references (ADR-0007).
   - **M9** inserts the internal-ALB hop between Web and App.
4. **References flow downward at plan time and upward at runtime.** A module may pass Terraform outputs from lower layers into a resource. Values that come from a higher layer (DB endpoint, internal ALB address) are read at boot via SSM (ADR-0006).
5. Each module ships: text lecture → guided walkthrough → checkpoint with expected results → reference solution, and states its **apply window and estimated cost** (ADR-0003).

## Options considered

| Option | Verdict |
|---|---|
| Independent mini-project per module | Rejected — contradicts the PRD's unified capstone; nothing converges. |
| One root per layer, chained with `terraform_remote_state` | Rejected — 8–10 state files and cross-state wiring is too heavy for self-paced learners and increases S3/state-lock surface. |
| **Single evolving root with modules, two roots total** | **Chosen** |

## Consequences

- Reference solutions are cumulative; any earlier module change must be re-verified against later modules.
- The dependency map (soldoc §3) is the change-impact tool: editing M6 outputs affects M7–M13.
- Lab order can never force a plan-time cycle, because upward references are runtime-only.
