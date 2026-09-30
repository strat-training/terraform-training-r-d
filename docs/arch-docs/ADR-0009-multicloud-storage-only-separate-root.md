# ADR-0009: Multi-cloud scope — storage-only, separate root, ALB origin by data source

- **Status:** Accepted; amended 2026-09-29 (azurerm 5.x)
- **Date:** 2026-09-28
- **Modules affected:** M14, M15, M16, M17
- **Related:** ADR-0002, ADR-0003, ADR-0010, ADR-0011, ADR-0012, soldoc gaps G8, G9

## Context

Week 4 adds a GCP backup bucket (M15) and an Azure static-asset bucket (M16). The PRD excludes complex cross-cloud routing and requires all three sandbox clouds to share one $5 budget. Two design tensions:

1. If these live in the same root as the AWS stack, every M15/M16 apply also touches the expensive AWS resources (or needs feature toggles across every module).
2. M16's CORS origin must be the **Web ALB address**, which changes every time the AWS stack is re-created, and the ALB has no TLS certificate or domain in this budget.

## Decision

1. **Separate root** `capstone/multicloud/` with its own state key. It declares all three providers together (M14): `aws` (`ap-southeast-1`), `google` (`asia-southeast1`), `azurerm` (`Southeast Asia`), with credentials from environment variables. Region inputs are variables (`aws_region`, `gcp_region`, `azure_location`) with the PRD defaults.
2. **Storage only, tiny data, no cross-cloud networking.**
   - **GCS (M15):** one bucket; `STANDARD` class; `uniform_bucket_level_access = true`; `public_access_prevention = "enforced"`; `force_destroy = true`; lifecycle rule moving objects **age ≥ 30 days to COLDLINE**. No automated RDS-dump job (manual `mysqldump` of a few KB is optional). The AWS side of "backup" is described, not automated.
   - **Azure (M16):** resource group, storage account (`StorageV2`, `Standard_LRS`, Hot tier, TLS 1.2 minimum, random name suffix because names are global, lowercase 3–24 chars), blob container with anonymous **blob**-level read for static assets, and CORS on the **storage account's blob service** (`blob_properties { cors_rule { … } }`), not on the container.
3. **CORS origin without coupling states:** a `data "aws_lb"` lookup by the deterministic name (`${project}-${workspace}-web-alb`) yields the ALB DNS; origin = `http://<dns>`. The lookup is gated by a boolean variable (`lookup_web_alb`, default `false`); when the AWS stack is down, a `web_origin_override` variable (default a placeholder) keeps plans valid. This also justifies the aws provider's presence in this root. The blob endpoint is HTTPS, so an HTTP page fetching it raises no mixed-content issue.
4. **Allowed CORS set:** methods `GET`, `HEAD`, `OPTIONS`; a bounded `max_age_in_seconds`; exact origin only (no wildcard).
5. Sandbox notes for azurerm 4.x: a `subscription_id` must be set; if the sandbox cannot register resource providers, disable automatic registration in the provider block.
6. GCS/Azure resources are created **only in their own 15-minute windows** and destroyed; the final integrated run applies AWS first, then multicloud, then destroys in reverse.

## Options considered

| Option | Verdict |
|---|---|
| Same root as AWS | Rejected — M15/M16 would drag AWS costs in or need toggles everywhere. |
| `terraform_remote_state` from the AWS root | Rejected — couples roots and workspaces, requires state-read IAM; a data-source lookup is simpler and reuses M3's data-source lesson. |
| Azure Front Door / Global routing to the ALB | Excluded by the PRD. |
| HTTPS on the Web ALB | Rejected — needs a domain and ACM certificate; out of budget/scope. |

## Consequences

- Cost of this tier is pennies. GCS's Always Free allowance covers only certain US regions, so `asia-southeast1` storage is billed at standard rates on trivially small data; keep region consistency with the PRD over chasing the free allowance. (Verify current GCS free-tier regions.)
- **The 30-day Coldline rule cannot be observed live** (Coldline also has a 90-day minimum storage duration); the checkpoint verifies the rule by plan and by reading the bucket's lifecycle configuration.
- The CORS checkpoint needs the Web ALB alive: run it inside the M9-onward window or the final integrated run.

## Amendment — 2026-09-29: azurerm 5.x

Provider versions were resolved for the course on 2026-09-28: `azurerm` **5.7.0** (not 4.x), `google` 8.4.0, `aws` 6.66.0 and `random` 3.9.1. Decision 5 changes as follows:
- `azurerm_storage_container` takes `storage_account_id`, and `azurerm_storage_blob` takes `storage_container_id`. The 4.x `storage_account_name`/`storage_container_name` arguments fail `terraform validate` on 5.x.
- The provider block still needs `subscription_id` (variable or `ARM_SUBSCRIPTION_ID`). Automatic registration is disabled with `resource_provider_registrations = "none"`.
- Mock assets are uploaded with `azurerm_storage_blob`, so `terraform destroy` removes them (ADR-0012).
