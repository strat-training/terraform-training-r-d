# ADR-0006: Runtime configuration through SSM Parameter Store; secrets access reconciliation

- **Status:** Accepted
- **Date:** 2026-09-28
- **Modules affected:** M5, M7, M8, M9, M10
- **Related:** ADR-0001, ADR-0005, ADR-0007, soldoc gaps G1, G2, G4

## Context

The curriculum builds compute (M8) before load balancers (M9) and the database (M10), yet the compute tier needs values from both: the Web tier needs the internal ALB address, and the App tier needs the DB endpoint and the secret's ARN. Injecting these into Launch Template user data with `templatefile()` would either create plan-time cycles or force Launch Template rewrites (new versions, instance refreshes, longer and costlier applies) every time a higher layer changes.

Additionally, M7 grants only **SSM Parameter Store** read access, while M10 stores the DB password in **Secrets Manager**. As written, the App role cannot read the secret (gap G1), and no role can reach the M5 uploads bucket (gap G2).

## Decision

1. **Rule:** values from *lower* layers are passed as Terraform inputs at plan time (for example the M5 storage bucket name into the compute module, as the PRD specifies). Values from *higher* layers are published to **SSM Parameter Store** and read by instances at boot.
2. **Parameter namespace:** `/${project}/${terraform.workspace}/…`
   - `db/endpoint`, `db/secret_arn` — published by the database module (M10)
   - `api/base_url` — internal ALB DNS name, published by the traffic module (M9)
   - `storage/uploads_bucket` — published by the storage module (M5)
3. **Standard-tier parameters only** (no charge). No advanced-tier or SecureString-with-custom-key parameters; sensitive material stays in Secrets Manager.
4. **User data behaviour:** boot scripts fetch parameters with the instance role and **retry with back-off** (bounded, several minutes) until they exist. Apply order between M8, M9 and M10 therefore never matters, and Launch Templates do not change when higher layers are added.
5. **IAM (extends M7's role, least privilege):**
   - `ssm:GetParameter`/`GetParametersByPath` on `/${project}/${terraform.workspace}/*`
   - `secretsmanager:GetSecretValue` on the **single DB secret ARN** (added in M10)
   - S3 object read/write on the **uploads bucket ARN** only (added with M5/M8 wiring)
   - No wildcard resources.
6. Web tier renders its Nginx upstream config at boot from `api/base_url`.

## Options considered

| Option | Verdict |
|---|---|
| `templatefile()` injection of later-layer values into Launch Templates | Rejected — plan-time cycles or Launch Template churn and instance refreshes. |
| Explicit `depends_on` ordering across layers | Rejected — hides the problem and still forces one-shot applies of everything. |
| Store everything in Secrets Manager | Rejected — per-secret monthly cost for non-secret values. |
| Instance user data pulling from Terraform outputs via remote state | Rejected — instances should not read state. |
| **SSM Parameter Store, bounded retry at boot** | **Chosen** |

## Consequences

- Instances that booted *before* a parameter existed retry; if the bounded window expires, terminate the instance (the ASG replaces it) — documented in the module checkpoints.
- Configuration changes take effect on next boot, not live; acceptable for a stateless immutable-infrastructure lesson (M8 lecture).
- The M7 lecture's least-privilege message is reinforced: paths and ARNs, not `*`.
