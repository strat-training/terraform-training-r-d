# Capstone: 3-Tier AWS Stack with Multi-Cloud Backup & Assets — Instructor Version

The same capstone as `modules/capstone-brief.md`, with the reference solution added. **Don't hand this to trainees.** They see only `README.md`, `modules/` and `data/`.

> **Provenance of the solution code.** Appendix A is the complete reference solution, including every module's Next steps. Each Next-step addition is marked `# Next step Mx Ny (instructor reference)`. It was checked on 2026-09-29 with Terraform 1.16.3 and the pinned providers (aws 6.66.0, random 3.9.1, google 8.4.0, azurerm 5.7.0):
> - `terraform fmt -check -recursive`;
> - `terraform init -backend=false` + `terraform validate` for `bootstrap/`, `capstone/aws/` and `capstone/multicloud/`;
> - `terraform test` with mocked providers (both guards);
> - a mocked plan of `capstone/aws` in `dev`: **75 resources to add**;
> - Checkov 3.x: 146 passed, 72 failed. Every remaining failure is an accepted, by-design trade-off for a $5 sandbox, or a cross-module false positive; they're listed in `knowledge/retros/2026-09-29-validate.md`.
>
> Every HCL block that trainees type in the guided labs was checked against this tree: the module code is identical, and the remaining differences are earlier stages that later modules replace on purpose.
>
> **The demo app (Flashcard Quiz)** is provided in `data/templates/`: a React 18.3.1 page (UMD from jsDelivr, pinned with SRI hashes) served by Nginx, and a Node.js v24.21.0 LTS API (tarball verified against the official SHA-256) using `mysql2` 3.24.4. The API was tested locally against **MySQL 8.4.11 in Docker**, with a stubbed AWS CLI: `/health`, `/db`, `/cards` (10), `/answers` (201, 400 on bad input), `/stats`, `/config`, 404, and idempotent seeding across a restart. The rendered boot scripts are 6.0 KB (web) and 6.9 KB (app), under the 16 KB user-data limit. The UI was syntax-checked but not rendered in a browser.
>
> **It has not yet been applied against real cloud accounts.** Outputs marked *expected* below should be replaced with your own dry-run log before the first cohort. Outputs marked *captured* are real local runs.

## Getting started

### Prerequisites

Terraform ≥ 1.11 (checked with 1.16.3), AWS CLI v2, Google Cloud CLI, Azure CLI, Git, Bash (or WSL 2). Sandbox accounts on AWS, GCP and Azure.

### Local setup: the integrated run (about 1.5 hours, about $0.36)

```bash
git clone <trainee-repository-url> tf-bootcamp && cd tf-bootcamp
```

**1. Bootstrap (once per account; never destroyed).**
```bash
cd bootstrap && terraform init && terraform apply -var 'budget_alert_emails=["instructor@example.com"]'
BUCKET=$(terraform output -raw state_bucket) && cd ..
printf 'bucket = "%s"\n' "$BUCKET" | tee capstone/aws/backend.hcl capstone/multicloud/backend.hcl
```

**2. AWS stack, `dev`.**
```bash
cd capstone/aws
terraform init -backend-config=backend.hcl
terraform workspace select -or-create dev
terraform plan -var-file=env/dev.tfvars -out=tfplan     # expected: Plan: 75 to add (with alert_email set)
terraform apply tfplan
```

**3. Multi-cloud root, with the Web ALB lookup on.**
```bash
cd ../multicloud && mkdir -p assets && cp ../../data/assets/* assets/
terraform init -backend-config=backend.hcl
terraform apply -var gcp_project="$(gcloud config get-value project)" -var lookup_web_alb=true
cd ../aws
```

**4.** Run "Validation & testing" below.

**5. Teardown, in reverse order.**
```bash
terraform -chdir=../multicloud destroy -var gcp_project="$(gcloud config get-value project)" -var lookup_web_alb=true
terraform destroy -var-file=env/dev.tfvars
terraform state list; terraform -chdir=../multicloud state list     # expected: both print nothing
```

### Data setup

The course's `data/` folder (visible to trainees): `templates/web.sh.tftpl` (Nginx + the React Flashcard Quiz), `templates/app.sh.tftpl` (Node.js API, which creates and seeds the `flashcards` and `answers` tables on first connect), `seed.sql` (the same tables and 10 cards, idempotent), `db-seed-and-dump.sh` (dumps the quiz DB from an App server; credentials go through a 0600 option file), `assets/` (theme + logo), and `bad.tfvars`.

## Business problem

> **Can one version-controlled Terraform codebase stand up a secure 3-tier
> application with off-site backups and offloaded static assets, prove it works
> (and fails safely), and leave nothing billable behind — for under $5?**

## Requirements / acceptance criteria

The same 18 requirements as the cohort version. Each is followed by **→ how the reference solution meets it** (Appendix A).

1. **Remote state.** → `bootstrap/main.tf`: versioning, SSE-S3, public-access block, `prevent_destroy`. Each root's `backend "s3"` uses `use_lockfile = true` and `encrypt = true`; the bucket comes from `backend.hcl` (partial configuration).
2. **Input validation.** → A `validation` block on `var.environment`.
3. **Environments.** → `terraform_data.workspace_guard` (two preconditions). `local.sizing` is keyed by workspace; prod gets ASGs 2–4 and `db.t4g.small`/30 GB.
4. **No hardcoded lookups.** → `data.aws_ami.ubuntu` (owner `099720109477`) and `slice(data.aws_availability_zones.available.names, 0, 2)`.
5. **Network.** → `modules/network`: one `local.subnets` map drives the subnets and the associations; the NAT, its EIP and the App route use `count = var.nat_gateway_enabled ? 1 : 0`; the DB route table has no route; an S3 gateway endpoint.
6. **Security-group chain.** → `modules/security-groups` expands `local.tier_rules` with `setproduct`. A CIDR source means edge ingress; a group name means an SG reference plus a mirrored egress rule. `internet_egress_ports` omits `db`.
7. **Least-privilege IAM.** → `modules/iam-instance-role` takes `policy_statements` from the root: SSM path, bucket, bucket objects, the one secret. The only managed policy is `AmazonSSMManagedInstanceCore`, with a comment.
8. **Self-healing compute.** → `modules/asg` is called twice. The Launch Template has IMDSv2 and standard credits; there's an instance refresh; `cpu_target_percent = 65` on `app_asg` only.
9. **Load balancing.** → `modules/alb` is called twice (`internal = false` on port 80; `internal = true` on port 8080 with `/health`).
10. **Data tier and secrets.** → `modules/rds-mysql`: MySQL `8.4`, single-AZ, private, encrypted. `random_password` → Secrets Manager (recovery window 0). The parameter group uses `name_prefix` + `create_before_destroy` (one reboot after first attaching it).
11. **Runtime configuration.** → The root's `local.runtime_config` → `aws_ssm_parameter.runtime` (4 parameters). The boot scripts retry (web 10 minutes, app 20 minutes).
12. **Alerting and dashboard.** → `modules/sns-topic`, three calls of `modules/cloudwatch-alarm`, and the root `aws_cloudwatch_dashboard`.
13. **Budget.** → `bootstrap/budget.tf`: ACTUAL 40, ACTUAL 80, FORECASTED 100.
14. **Multi-cloud root.** → `capstone/multicloud/main.tf`: its own state key, three pinned providers, no credentials, `resource_provider_registrations = "none"`.
15. **Off-site backup.** → `google_storage_bucket.db_backups` (UBLA, PAP enforced, lifecycle 30 days → COLDLINE). Dump path: `data/db-seed-and-dump.sh`.
16. **Static assets and CORS.** → `blob_properties.cors_rule` on the storage account, with the exact origin from `data.aws_lb.web` (gated by `lookup_web_alb`); the container has `container_access_type = "blob"`.
17. **Module structure.** → Nine per-resource modules plus `network`. `alb` and `asg` are each called twice. Child modules pin `>= 6.0` only.
18. **Lifecycle and hygiene.** → Provider `default_tags` (`Project`, `Env`, `Teardown`, `ManagedBy`) and `local.name_prefix`. Everything is a Terraform resource; data files sit only in `force_destroy` buckets.

## Deliverable

| Output | Expected value / shape |
|---|---|
| `terraform output web_url` | `http://tf-bootcamp-dev-web-alb-<id>.ap-southeast-1.elb.amazonaws.com` |
| Browser at `web_url` | **Terraform Flashcards**: 10 cards; the score persists across a reload; the footer shows *Answered by App server: ip-10-0-1x-…* and *Azure Blob ✓ (CORS allowed)* (purple theme + logo) |
| `curl $web_url` | HTML containing `<title>Terraform Flashcards</title>` |
| `curl $web_url/api/health` | `{"status":"ok"}` |
| `curl $web_url/api/db` | `{"db":"reachable","host":"tf-bootcamp-dev-db.<id>.ap-southeast-1.rds.amazonaws.com"}` |
| `curl $web_url/api/cards` | a JSON array of 10 cards |
| GCS | object `rds/app-dump-<timestamp>.sql`, a few KB, with the `flashcards` rows and the trainee's `answers` |
| Azure | `<asset_base_url>/app.css` → `200 text/css` |
| Teardown | `Destroy complete! Resources: 75 destroyed.` for `capstone/aws`; `terraform state list` prints nothing in either root |

## Project architecture

See `modules/capstone-requirements.md` §Architecture: the code map, the "how it runs" diagram, the module wiring diagram and table, and the running-system picture.

## Technology stack

As in the cohort version. Trainee module → topic: M1 state/validation · M2 data sources/iteration · M3 modules · M4 network · M5 security groups/IAM · M6 ALB/ASG · M7 RDS/secrets · M8 workspaces · M9 monitoring/budget · M10 integrated deployment · M11 GCP · M12 Azure.

## Key engineering features

- **Bootstrap root with local state** owns the state bucket (`prevent_destroy`). The capstone roots use partial backend configuration, so no account ID is committed.
- **Plan-time guards:** validation, plus two workspace preconditions and the NAT precondition. `terraform test` with `mock_provider` proves the first two at $0.
- **Per-resource modules:** the root is the only place resources meet. It owns the cross-cutting pieces (the SSM `runtime_config` map, the dashboard, the IAM statements), so each module stays reusable.
- **Security-group chain as data:** `setproduct(ports, sources)` over one map, with standalone rule resources (inline cross-references would cycle).
- **Runtime config through SSM:** Launch Templates never reference later layers, so apply order is irrelevant.
- **Secrets:** `random_password` → Secrets Manager; the plan shows `(sensitive value)`; the value is still in state, which is covered in M7.
- **Demo app:** the Flashcard Quiz is course-provided. `/health` never touches the DB, so ALB health stays green while RDS is still being created. The API connects to MySQL lazily on the first request after the DB endpoint appears in SSM, and seeds idempotently. `/stats` returns `servedBy` (the hostname), which makes load balancing and self-healing visible in the browser.
- **Cost:** one flagged NAT, standard CPU credits, and RDS without backups. `force_destroy` and recovery window 0 make destroy/re-apply idempotent. Teardown is `terraform destroy` plus an empty `terraform state list`.

## Validation & testing

`run_on_tier` is the helper from M6 (SSM Run Command; no SSH).

### Happy path

**H1: Web, API and DB path (req. 9, 10).** *Expected:*
```text
<title>Terraform Flashcards</title>
{"status":"ok"}
{"db":"reachable","host":"tf-bootcamp-dev-db.xxxxxxxxxxxx.ap-southeast-1.rds.amazonaws.com"}
```
The `/health`, `/db` and `/cards` response shapes above were *captured* against MySQL 8.4.11 locally; the host names are *expected*. In the browser, answer a card and check `POST /api/answers` returns `201` with `{"answered":…,"correct":…,"servedBy":"ip-…"}`.

**H2: Seed → dump → GCS (req. 15).** *Expected:*
```bash
UPLOADS=$(terraform output -raw uploads_bucket)
aws s3 cp ../../data/seed.sql "s3://$UPLOADS/seed/seed.sql"
aws s3 cp ../../data/db-seed-and-dump.sh "s3://$UPLOADS/seed/db-seed-and-dump.sh"
run_on_tier app "aws s3 cp s3://$UPLOADS/seed/db-seed-and-dump.sh /tmp/ && bash /tmp/db-seed-and-dump.sh $UPLOADS /tf-bootcamp/dev"
aws s3 cp "s3://$UPLOADS/backups/app-dump.sql" ./app-dump.sql
gcloud storage cp app-dump.sql "gs://$(terraform -chdir=../multicloud output -raw gcs_backup_bucket)/rds/app-dump-$(date -u +%Y%m%dT%H%M%SZ).sql"
grep -c 'INSERT INTO `flashcards`' app-dump.sql              # expected: 1 (one extended INSERT with 10 rows)
# The run_on_tier output shows: FLASHCARDS 10 · ANSWERS <how many the trainee answered> · DUMP_OK <bytes>
```

**H3: Assets and CORS (req. 16).** *Expected:* `200 text/css` for `app.css`, `200` for a preflight from the Web ALB's origin, and the quiz footer showing *Azure Blob ✓ (CORS allowed)* after a reload. With `lookup_web_alb=false` (the origin falls back to localhost), the footer shows *✗ (blocked by CORS)*.

**H4: Alarm email (req. 12).** *Expected:* "ALARM: tf-bootcamp-dev-app-cpu-high" within about a minute of `aws cloudwatch set-alarm-state … --state-value ALARM`.

**H5: Guards proven at $0 (req. 2, 3).** *Captured* (`terraform test`, mocked providers):
```text
tests/guards.tftest.hcl... in progress
  run "rejects_unknown_environment"... pass
  run "rejects_default_workspace"... pass
tests/guards.tftest.hcl... tearing down
tests/guards.tftest.hcl... pass

Success! 2 passed, 0 failed.
```

### Failure proofs

**F1: Invalid input (req. 2).** *Captured*:
```text
Error: Invalid value for variable

  on bad.tfvars line 1:
   1: environment = "qa"
    ├────────────────
    │ var.environment is "qa"

environment must be one of: dev, staging, prod.
```

**F2: Wrong workspace (req. 3).** *Captured*:
```text
Error: Resource precondition failed
…
    │ terraform.workspace is "default"

Select the dev or prod workspace (terraform workspace select dev). The
default workspace is not used.
```
A second precondition (`var.environment must match the workspace…`) also fires in `default`. Seeing both is correct.

**F3: Web tier cannot reach RDS (req. 6).** *Expected:* `BLOCKED` from every Web server.

**F4: Self-healing (req. 8).** *Expected:* within about 5 minutes, a new `InService` instance appears, and the App target group is `healthy` again.

**F5: Foreign origin denied (req. 16).** *Expected:* `403` for a preflight with `Origin: http://evil.example`.

### Teardown (req. 18)
*Expected:* `Destroy complete!` for each root, then no output from `terraform state list` in either. Ask the trainee: "Did you create anything in a console?" The answer must be no.

## Output & usage notes

- `web_url` is plain HTTP; there's no TLS or custom domain, because of the budget.
- The Coldline transition and the forecast budget alert can't be observed within one session; grade them by configuration.
- `tf-bootcamp-prod-*` resources in the account mean prod was applied; that isn't allowed.

## Repository structure

```text
tf-bootcamp/
├── bootstrap/                 PERSISTENT: main.tf (state bucket), budget.tf
├── modules/
│   ├── ec2-instance/          M3 prototype only
│   ├── s3-bucket/             uploads bucket
│   ├── network/               VPC, subnets, IGW, flagged NAT, route tables, S3 endpoint (grouped)
│   ├── security-groups/       every tier's group + chain rules from one map
│   ├── iam-instance-role/     role, inline policy, SSM core, instance profile
│   ├── alb/                   LB + target group + listener (called twice)
│   ├── asg/                   Launch Template + ASG + optional CPU policy (called twice)
│   ├── rds-mysql/             password, secret, subnet group, parameter group, instance
│   ├── sns-topic/             topic + optional email subscription
│   └── cloudwatch-alarm/      one alarm (called three times)
├── capstone/
│   ├── aws/                   EPHEMERAL root: main.tf, variables.tf, versions.tf, outputs.tf, env/, templates/, tests/
│   └── multicloud/            EPHEMERAL root: main.tf (google + azurerm + aws lookup), assets/
└── EVIDENCE.md
```

## Documentation

- Trainee evidence: `EVIDENCE.md` (contents are listed in `modules/capstone-brief.md`; grading is in `capstone-grading-rubric.md` §3).
- Design sources: `docs/arch-docs/soldoc.md`, ADR-0001 … ADR-0014.

**Instructor notes: where the course differs from the original design documents**
1. **Parameter-group reboot.** A newly associated group applies only after one reboot (ADR-0005 amendment).
2. **Per-resource modules.** The soldoc §6 layered modules (`compute/`, `traffic/`, `database/`, `observability/`) are replaced by one module per resource type (ADR-0014).
3. **azurerm 5.x.** `azurerm_storage_blob` takes `storage_container_id` (ADR-0009 amendment).
4. **M8 challenge.** A larger prod RDS via the sizing map; dual NAT is a plan-only stretch (ADR-0004, ADR-0008).
5. **No teardown script.** Teardown is `terraform destroy` plus an empty `terraform state list` (ADR-0012).
6. **CI/CD out of scope.** The PRD's M17 (and ADR-0010/0011) are removed from the bootcamp (ADR-0013).
7. **17 → 12 modules.** The course merges the PRD's 17 modules into 12, and adds M10, the integrated deployment (soldoc §12 mapping).

## Checkpoint (self-assessed)

Mirrors the requirements; expected answers are in *italics*.

- [ ] 1. Remote state hardened; native locking. — *`get-bucket-versioning` → `Enabled`; no `dynamodb_table`.*
- [ ] 2. `bad.tfvars` fails. — *See F1.*
- [ ] 3. `default` fails; prod plans larger. — *See F2; the prod plan shows `min_size = 2` and `db.t4g.small`.*
- [ ] 4. No hardcoded AMI/AZ. — *`grep -rn 'ami-[0-9a-f]\{8\}\|ap-southeast-1[abc]' --include=*.tf .` → nothing.*
- [ ] 5. Network. — *6 subnets, 6 associations; `aws_route.app_nat` absent when the flag is false.*
- [ ] 6. SG chain. — *See F3; the DB group has 1 ingress and 0 egress rules.*
- [ ] 7. IAM. — *The inline policy lists the SSM path, the bucket, bucket/\*, and the secret ARN only.*
- [ ] 8. Self-healing. — *See F4.*
- [ ] 9. ALBs. — *See H1; the Flashcard Quiz loads.*
- [ ] 10. RDS and secret. — *See H1; attaching the parameter group plans `~ update in-place`.*
- [ ] 11. SSM. — *`get-parameters-by-path --path /tf-bootcamp/dev --recursive` → 4 parameters.*
- [ ] 12. Alarms. — *See H4; 3 alarms.*
- [ ] 13. Budget. — *ACTUAL 40, ACTUAL 80, FORECASTED 100.*
- [ ] 14. Multi-cloud root. — *`terraform providers` → aws 6.66.0, google 8.4.0, azurerm 5.7.0, random 3.9.1.*
- [ ] 15. Backup. — *See H2; the dump holds the cards and the trainee's answers.*
- [ ] 16. CORS. — *See H3 and F5.*
- [ ] 17. Modules. — *`ls modules/` shows the 10 modules; `grep -c 'source = "../../modules/alb"'` → 2.*
- [ ] 18. Hygiene. — *See Teardown.*

## Project scope

Provision, prove and destroy a small 3-tier stack plus two storage services, from Terraform only. Out of scope: HTTPS or custom domains, Multi-AZ, automated backups, cross-cloud networking, AWS Organizations/SCPs, billing APIs, paid SaaS, policy-as-code, and **CI/CD pipelines**.

---

## Appendix A — Reference solution (validated files)

### `bootstrap/main.tf`

```hcl
terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.66.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

variable "project" {
  type    = string
  default = "tf-bootcamp"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "state" {
  # Your account ID makes the name globally unique.
  bucket = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true # a stray `destroy` can never delete everyone's state
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled" # every state change keeps the previous version
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}
```

### `bootstrap/budget.tf`

```hcl
variable "budget_alert_emails" { type = list(string) }

resource "aws_budgets_budget" "account" {
  name         = "${var.project}-monthly"
  budget_type  = "COST"
  limit_amount = "5"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 40 # $2: stop and check what is running
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  # Next step M9 N2 (instructor reference)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80 # $4
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }
}
```

### `modules/ec2-instance/main.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

variable "name" { type = string }
variable "ami_id" { type = string }
variable "availability_zone" { type = string }
variable "security_group_ids" { type = list(string) }

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  availability_zone      = var.availability_zone
  vpc_security_group_ids = var.security_group_ids

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = var.name }
}

output "id" {
  value = aws_instance.this.id
}

output "public_ip" {
  value = aws_instance.this.public_ip
}
```

### `modules/s3-bucket/main.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

variable "name" { type = string }

variable "force_destroy" {
  description = "Delete the bucket even if it still holds files (lab buckets only)."
  type        = bool
  default     = false
}

resource "aws_s3_bucket" "this" {
  bucket        = var.name
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "name" {
  value = aws_s3_bucket.this.bucket
}

output "arn" {
  value = aws_s3_bucket.this.arn
}
```

### `modules/network/versions.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}
```

### `modules/network/main.tf`

```hcl
variable "name_prefix" { type = string }
variable "azs" { type = list(string) }

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "nat_gateway_enabled" {
  description = "Create the single NAT Gateway (billed hourly)."
  type        = bool
  default     = true
}

data "aws_region" "current" {}

locals {
  # Tier => third-octet offset: web 10.0.0-1.x, app 10.0.10-11.x, db 10.0.20-21.x
  tier_offsets = { web = 0, app = 10, db = 20 }

  subnets = merge([
    for tier, offset in local.tier_offsets : {
      for i, az in var.azs : "${tier}-${i}" => {
        tier = tier
        az   = az
        cidr = cidrsubnet(var.vpc_cidr, 8, offset + i)
      }
    }
  ]...)
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name_prefix}-vpc" }
}

resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.tier == "web"
  tags                    = { Name = "${var.name_prefix}-${each.key}", Tier = each.value.tier }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_eip" "nat" {
  count  = var.nat_gateway_enabled ? 1 : 0
  domain = "vpc"
}

resource "aws_nat_gateway" "this" {
  count         = var.nat_gateway_enabled ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.this["web-0"].id
  depends_on    = [aws_internet_gateway.this] # AWS needs the IGW first; no attribute shows that
}

resource "aws_route_table" "this" {
  for_each = local.tier_offsets
  vpc_id   = aws_vpc.this.id
  tags     = { Name = "${var.name_prefix}-${each.key}-rt" }
}

resource "aws_route" "web_internet" {
  route_table_id         = aws_route_table.this["web"].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route" "app_nat" {
  count                  = var.nat_gateway_enabled ? 1 : 0
  route_table_id         = aws_route_table.this["app"].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

# The DB route table deliberately has no default route.

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.this["app"].id, aws_route_table.this["db"].id]
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "subnet_ids" {
  description = "Subnet IDs per tier: { web = [...], app = [...], db = [...] }"
  value = {
    for tier in keys(local.tier_offsets) :
    tier => [for key, subnet in aws_subnet.this : subnet.id if local.subnets[key].tier == tier]
  }
}

# Next step M4 N1 (instructor reference)
resource "aws_route_table_association" "this" {
  for_each       = local.subnets
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.value.tier].id
}
```

### `modules/security-groups/main.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

variable "name_prefix" { type = string }
variable "vpc_id" { type = string }

variable "tier_rules" {
  description = "Group name => ports and sources. A source is a CIDR (internet edge only) or another group's name."
  type = map(object({
    ports   = list(number)
    sources = list(string)
  }))
}

variable "internet_egress_ports" {
  type    = map(list(number))
  default = {}
}

locals {
  ingress = merge([
    for group, rule in var.tier_rules : {
      for pair in setproduct(rule.ports, rule.sources) :
      "${group}-${pair[0]}-from-${replace(pair[1], "/", "_")}" => {
        group   = group
        port    = pair[0]
        source  = pair[1]
        is_cidr = can(cidrhost(pair[1], 0))
      }
    }
  ]...)

  # Every group-to-group ingress gets a matching egress on the source group.
  chain_egress = { for key, rule in local.ingress : key => rule if !rule.is_cidr }

  internet_egress = merge([
    for group, ports in var.internet_egress_ports : {
      for port in ports : "${group}-${port}-to-internet" => { group = group, port = port }
    }
  ]...)
}

resource "aws_security_group" "tier" {
  for_each    = var.tier_rules
  name        = "${var.name_prefix}-${each.key}-sg"
  description = "${each.key} tier (managed by Terraform)"
  vpc_id      = var.vpc_id
  # Terraform removes AWS's default allow-all egress rule; only the rules below exist.
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = local.ingress

  security_group_id            = aws_security_group.tier[each.value.group].id
  description                  = each.key
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  cidr_ipv4                    = each.value.is_cidr ? each.value.source : null
  referenced_security_group_id = each.value.is_cidr ? null : aws_security_group.tier[each.value.source].id
}

resource "aws_vpc_security_group_egress_rule" "chain" {
  for_each = local.chain_egress

  security_group_id            = aws_security_group.tier[each.value.source].id
  description                  = "to ${each.value.group}:${each.value.port}"
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  referenced_security_group_id = aws_security_group.tier[each.value.group].id
}

resource "aws_vpc_security_group_egress_rule" "internet" {
  for_each = local.internet_egress

  security_group_id = aws_security_group.tier[each.value.group].id
  description       = each.key
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  cidr_ipv4         = "0.0.0.0/0" # outbound only: package installs and AWS APIs at boot
}

output "ids" {
  description = "Security group ID per group name."
  value       = { for name, sg in aws_security_group.tier : name => sg.id }
}
```

### `modules/iam-instance-role/main.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

variable "name" { type = string }

variable "policy_statements" {
  description = "What the instances may do: a list of { actions, resources }. Never use \"*\" resources."
  type = list(object({
    actions   = list(string)
    resources = list(string)
  }))
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "inline" {
  dynamic "statement" {
    for_each = var.policy_statements
    content {
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "inline" {
  name   = "${var.name}-inline"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.inline.json
}

# AWS-managed policy for Systems Manager Run Command: no SSH keys, no port 22.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = var.name
  role = aws_iam_role.this.name
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.this.name
}
```

### `modules/alb/main.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

variable "name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
variable "internal" { type = bool }
variable "port" { type = number }
variable "health_check_path" { type = string }

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = var.internal
  subnets            = var.subnet_ids
  security_groups    = [var.security_group_id]
}

resource "aws_lb_target_group" "this" {
  name                 = "${var.name}-tg"
  port                 = var.port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path     = var.health_check_path
    matcher  = "200"
    interval = 15
  }
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

output "dns_name" {
  value = aws_lb.this.dns_name
}

output "arn_suffix" {
  description = "The LoadBalancer dimension for CloudWatch metrics."
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}
```

### `modules/asg/main.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

variable "name" { type = string }
variable "ami_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "instance_profile_name" { type = string }
variable "user_data" { type = string }
variable "min_size" { type = number }
variable "max_size" { type = number }

variable "target_group_arns" {
  type    = list(string)
  default = []
}

resource "aws_launch_template" "this" {
  name_prefix            = "${var.name}-"
  image_id               = var.ami_id
  instance_type          = "t3.micro"
  user_data              = base64encode(var.user_data)
  vpc_security_group_ids = var.security_group_ids

  iam_instance_profile {
    name = var.instance_profile_name
  }

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens = "required"
  }

  block_device_mappings {
    device_name = "/dev/sda1" # Ubuntu's root volume

    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = var.name }
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = "${var.name}-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.min_size
  vpc_zone_identifier       = var.subnet_ids
  target_group_arns         = var.target_group_arns
  health_check_type         = length(var.target_group_arns) > 0 ? "ELB" : "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  instance_refresh {
    strategy = "Rolling" # replace instances when the template changes
  }
}

output "name" {
  value = aws_autoscaling_group.this.name
}

# Next step M6 N1 (instructor reference)
variable "cpu_target_percent" {
  type    = number
  default = null
}

resource "aws_autoscaling_policy" "cpu" {
  count                  = var.cpu_target_percent == null ? 0 : 1
  name                   = "${var.name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_percent
  }
}
```

### `modules/rds-mysql/main.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}

variable "name" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage_gb" {
  type    = number
  default = 20
}

resource "random_password" "master" {
  length           = 24
  override_special = "!#%^*()-_=+[]{}<>?" # RDS rejects /, @, " and spaces
}

resource "aws_secretsmanager_secret" "master" {
  name                    = "${var.name}/db/master"
  recovery_window_in_days = 0 # delete at once, so the next session can reuse the name
}

resource "aws_secretsmanager_secret_version" "master" {
  secret_id     = aws_secretsmanager_secret.master.id
  secret_string = jsonencode({ username = "appadmin", password = random_password.master.result })
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.subnet_ids
}

resource "aws_db_instance" "this" {
  identifier             = "${var.name}-db"
  engine                 = "mysql"
  engine_version         = "8.4"
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage_gb
  storage_type           = "gp3"
  storage_encrypted      = true
  db_name                = "app"
  username               = "appadmin"
  password               = random_password.master.result
  multi_az               = false
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  parameter_group_name   = aws_db_parameter_group.mysql.name # Next step M7 N1

  # Lab settings: nothing bills after destroy, nothing blocks destroy.
  backup_retention_period = 0
  skip_final_snapshot     = true
  apply_immediately       = true
}

output "address" {
  value = aws_db_instance.this.address
}

output "identifier" {
  value = aws_db_instance.this.identifier
}

output "secret_arn" {
  value = aws_secretsmanager_secret.master.arn
}

# Next step M7 N1 (instructor reference)
resource "aws_db_parameter_group" "mysql" {
  name_prefix = "${var.name}-mysql84-"
  family      = "mysql8.4"

  parameter {
    name         = "slow_query_log"
    value        = "1"
    apply_method = "immediate"
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

### `modules/sns-topic/main.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

variable "name" { type = string }

variable "email" {
  description = "Subscriber email. Empty = no subscription."
  type        = string
  default     = ""
}

resource "aws_sns_topic" "this" {
  name = var.name
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.email == "" ? 0 : 1
  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = var.email # AWS emails a confirmation link: click it
}

output "arn" {
  value = aws_sns_topic.this.arn
}
```

### `modules/cloudwatch-alarm/main.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

variable "name" { type = string }
variable "namespace" { type = string }
variable "metric_name" { type = string }
variable "dimensions" { type = map(string) }
variable "statistic" { type = string }
variable "comparison_operator" { type = string }
variable "threshold" { type = number }
variable "alarm_actions" { type = list(string) }

variable "period" {
  type    = number
  default = 300
}

variable "evaluation_periods" {
  type    = number
  default = 1
}

variable "treat_missing_data" {
  type    = string
  default = "missing"
}

resource "aws_cloudwatch_metric_alarm" "this" {
  alarm_name          = var.name
  namespace           = var.namespace
  metric_name         = var.metric_name
  dimensions          = var.dimensions
  statistic           = var.statistic
  period              = var.period
  evaluation_periods  = var.evaluation_periods
  threshold           = var.threshold
  comparison_operator = var.comparison_operator
  treat_missing_data  = var.treat_missing_data
  alarm_actions       = var.alarm_actions
}
```

### `capstone/aws/versions.tf`

```hcl
terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.66.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
  }
  backend "s3" {
    key          = "capstone/aws/terraform.tfstate" # the file's path inside the bucket
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true # S3 native locking: no DynamoDB table needed
  }
}

provider "aws" {
  region = var.aws_region

  # Next step M1 N1 (instructor reference)
  default_tags {
    tags = {
      Project   = var.project
      Env       = terraform.workspace
      Teardown  = "every-session"
      ManagedBy = "terraform"
    }
  }
}
```

### `capstone/aws/variables.tf`

```hcl
variable "project" {
  type    = string
  default = "tf-bootcamp"
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "nat_gateway_enabled" {
  type    = bool
  default = true
}

variable "alert_email" {
  type    = string
  default = ""
}
```

### `capstone/aws/main.tf`

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project}-${terraform.workspace}"
  ssm_prefix  = "/${var.project}/${terraform.workspace}"
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)

  sizing = {
    # db_* keys: Next step M8 N1 (instructor reference)
    dev  = { web_min = 1, web_max = 2, app_min = 1, app_max = 2, db_class = "db.t4g.micro", db_storage = 20 }
    prod = { web_min = 2, web_max = 4, app_min = 2, app_max = 4, db_class = "db.t4g.small", db_storage = 30 }
  }
  size = local.sizing[terraform.workspace == "prod" ? "prod" : "dev"]

  tier_rules = {
    web_alb = { ports = [80], sources = ["0.0.0.0/0"] } # the only internet-facing ingress
    web     = { ports = [80], sources = ["web_alb"] }
    app_alb = { ports = [8080], sources = ["web"] }
    app     = { ports = [8080], sources = ["app_alb"] }
    db      = { ports = [3306], sources = ["app"] }
  }

  # Values the servers read at boot. Each module that learns one adds it here.
  runtime_config = {
    "storage/uploads_bucket" = module.uploads_bucket.name
    "api/base_url"           = "http://${module.app_alb.dns_name}:8080"
    "db/endpoint"            = module.rds.address
    "db/secret_arn"          = module.rds.secret_arn
  }
}

resource "terraform_data" "workspace_guard" {
  lifecycle {
    precondition {
      condition     = contains(["dev", "prod"], terraform.workspace)
      error_message = "Select the dev or prod workspace (terraform workspace select dev). The default workspace is not used."
    }
    precondition {
      condition     = var.environment == terraform.workspace
      error_message = "var.environment must match the workspace. Use -var-file=env/${terraform.workspace}.tfvars."
    }
  }
}

resource "terraform_data" "nat_guard" {
  lifecycle {
    precondition {
      condition     = var.nat_gateway_enabled || local.size.app_min == 0
      error_message = "App instances need the NAT Gateway. Set nat_gateway_enabled = true."
    }
  }
}

# ---------- storage
module "uploads_bucket" {
  source = "../../modules/s3-bucket"

  name          = "${local.name_prefix}-uploads-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # lab bucket: destroy must never be blocked by leftover files
}

# ---------- network and security
module "network" {
  source = "../../modules/network"

  name_prefix         = local.name_prefix
  azs                 = local.azs
  nat_gateway_enabled = var.nat_gateway_enabled
}

module "security_groups" {
  source = "../../modules/security-groups"

  name_prefix           = local.name_prefix
  vpc_id                = module.network.vpc_id
  tier_rules            = local.tier_rules
  internet_egress_ports = { web = [80, 443], app = [80, 443] } # db removed: Next step M5 N1
}

module "instance_role" {
  source = "../../modules/iam-instance-role"

  name = "${local.name_prefix}-instance"
  policy_statements = [
    {
      actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
      resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_prefix}/*"]
    },
    {
      actions   = ["s3:ListBucket"]
      resources = [module.uploads_bucket.arn]
    },
    {
      actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
      resources = ["${module.uploads_bucket.arn}/*"]
    },
    {
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [module.rds.secret_arn]
    },
  ]
}

resource "aws_ssm_parameter" "runtime" {
  for_each = local.runtime_config

  name  = "${local.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value
}

# ---------- load balancers
module "web_alb" {
  source = "../../modules/alb"

  name              = "${local.name_prefix}-web"
  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.subnet_ids["web"]
  security_group_id = module.security_groups.ids["web_alb"]
  internal          = false
  port              = 80
  health_check_path = "/"
}

module "app_alb" {
  source = "../../modules/alb"

  name              = "${local.name_prefix}-app"
  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.subnet_ids["app"]
  security_group_id = module.security_groups.ids["app_alb"]
  internal          = true
  port              = 8080
  health_check_path = "/health"
}

# ---------- Auto Scaling groups
module "web_asg" {
  source = "../../modules/asg"

  name                  = "${local.name_prefix}-web"
  ami_id                = data.aws_ami.ubuntu.id
  subnet_ids            = module.network.subnet_ids["web"]
  security_group_ids    = [module.security_groups.ids["web"]]
  instance_profile_name = module.instance_role.instance_profile_name
  min_size              = local.size.web_min
  max_size              = local.size.web_max
  target_group_arns     = [module.web_alb.target_group_arn]
  user_data             = templatefile("${path.module}/templates/web.sh.tftpl", { region = var.aws_region, ssm_prefix = local.ssm_prefix })
}

module "app_asg" {
  source = "../../modules/asg"

  name                  = "${local.name_prefix}-app"
  ami_id                = data.aws_ami.ubuntu.id
  subnet_ids            = module.network.subnet_ids["app"]
  security_group_ids    = [module.security_groups.ids["app"]]
  instance_profile_name = module.instance_role.instance_profile_name
  min_size              = local.size.app_min
  max_size              = local.size.app_max
  target_group_arns     = [module.app_alb.target_group_arn]
  cpu_target_percent    = 65 # Next step M6 N1
  user_data             = templatefile("${path.module}/templates/app.sh.tftpl", { region = var.aws_region, ssm_prefix = local.ssm_prefix })
}

# ---------- database
module "rds" {
  source = "../../modules/rds-mysql"

  name              = local.name_prefix
  subnet_ids        = module.network.subnet_ids["db"]
  security_group_id = module.security_groups.ids["db"]

  # Next step M8 N1 (instructor reference)
  instance_class       = local.size.db_class
  allocated_storage_gb = local.size.db_storage
}

# ---------- monitoring
module "alerts" {
  source = "../../modules/sns-topic"

  name  = "${local.name_prefix}-alerts"
  email = var.alert_email
}

module "alarm_app_cpu" {
  source = "../../modules/cloudwatch-alarm"

  name                = "${local.name_prefix}-app-cpu-high"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { AutoScalingGroupName = module.app_asg.name }
  statistic           = "Average"
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  alarm_actions       = [module.alerts.arn]
}

module "alarm_web_5xx" {
  source = "../../modules/cloudwatch-alarm"

  name                = "${local.name_prefix}-web-alb-5xx"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  dimensions          = { LoadBalancer = module.web_alb.arn_suffix }
  statistic           = "Sum"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 5
  treat_missing_data  = "notBreaching" # no traffic means no errors
  alarm_actions       = [module.alerts.arn]
}

# Next step M9 N1 (instructor reference)
module "alarm_rds_storage" {
  source = "../../modules/cloudwatch-alarm"

  name                = "${local.name_prefix}-rds-free-storage-low"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = module.rds.identifier }
  statistic           = "Minimum"
  comparison_operator = "LessThanThreshold"
  threshold           = 2 * 1024 * 1024 * 1024 # bytes
  alarm_actions       = [module.alerts.arn]
}

resource "aws_cloudwatch_dashboard" "stack" {
  dashboard_name = "${local.name_prefix}-3tier"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Tier CPU (%)"
          region = var.aws_region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", module.web_asg.name],
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", module.app_asg.name],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Web ALB requests"
          region  = var.aws_region
          stat    = "Sum"
          period  = 300
          metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.web_alb.arn_suffix]]
        }
      },
    ]
  })
}
```

### `capstone/aws/outputs.tf`

```hcl
output "web_url" {
  value = "http://${module.web_alb.dns_name}"
}

output "uploads_bucket" {
  value = module.uploads_bucket.name
}

output "db_secret_arn" {
  value = module.rds.secret_arn
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.stack.dashboard_name
}
```

### `capstone/aws/env/dev.tfvars`

```hcl
environment = "dev"
```

### `capstone/aws/env/prod.tfvars`

```hcl
environment = "prod"
```

### `capstone/aws/tests/guards.tftest.hcl`

```hcl
# Runs with `terraform test`: mocked providers, no credentials, $0.
mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"] }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_region" {
    defaults = { region = "ap-southeast-1" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
}

mock_provider "random" {}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}

run "rejects_default_workspace" {
  command = plan

  variables {
    environment = "dev"
  }

  # `terraform test` runs in the default workspace, so the guard must fire.
  expect_failures = [terraform_data.workspace_guard]
}
```

### `capstone/multicloud/main.tf`

```hcl
terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws     = { source = "hashicorp/aws", version = "6.66.0" }
    google  = { source = "hashicorp/google", version = "8.4.0" }
    random  = { source = "hashicorp/random", version = "3.9.1" }
    azurerm = { source = "hashicorp/azurerm", version = "5.7.0" }
  }
  backend "s3" {
    key          = "capstone/multicloud/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

variable "gcp_project" { type = string }

variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "gcp_region" {
  type    = string
  default = "asia-southeast1"
}

# No credentials here: each provider uses your shell login.
provider "aws" {
  region = var.aws_region
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

locals {
  name_prefix = "tf-bootcamp-dev"
}

resource "random_string" "suffix" { # bucket names are global, so add a random suffix
  length  = 6
  upper   = false
  special = false
}

resource "google_storage_bucket" "db_backups" {
  name          = "${local.name_prefix}-db-backups-${random_string.suffix.result}"
  location      = upper(var.gcp_region)
  storage_class = "STANDARD"
  force_destroy = true

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced" # can never be made public

  # Next step M11 N1 (instructor reference)
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }
}

output "gcs_backup_bucket" {
  value = google_storage_bucket.db_backups.name
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none" # sandboxes often forbid registering providers
}

variable "azure_location" {
  type    = string
  default = "Southeast Asia"
}

variable "lookup_web_alb" {
  description = "true only while the M10 stack is up."
  type        = bool
  default     = false
}

# The ALB lives in another root: find it by its predictable name.
data "aws_lb" "web" {
  count = var.lookup_web_alb ? 1 : 0
  name  = "${local.name_prefix}-web-alb"
}

locals {
  web_origin = var.lookup_web_alb ? "http://${data.aws_lb.web[0].dns_name}" : "http://localhost:8080"
}

resource "azurerm_resource_group" "assets" {
  name     = "${local.name_prefix}-assets-rg"
  location = var.azure_location
}

resource "azurerm_storage_account" "assets" {
  name                            = "tfbcdev${random_string.suffix.result}" # lowercase letters/digits, 3-24 chars
  resource_group_name             = azurerm_resource_group.assets.name
  location                        = azurerm_resource_group.assets.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = true

  # CORS belongs to the account's blob service, not to the container.
  blob_properties {
    cors_rule {
      allowed_origins    = [local.web_origin] # exact origin, never "*"
      allowed_methods    = ["GET", "HEAD", "OPTIONS"]
      allowed_headers    = ["*"]
      exposed_headers    = ["Content-Length", "Content-Type"]
      max_age_in_seconds = 3600
    }
  }
}

resource "azurerm_storage_container" "assets" {
  name                  = "assets"
  storage_account_id    = azurerm_storage_account.assets.id
  container_access_type = "blob" # anyone can read a file by its URL; nobody can list
}

resource "azurerm_storage_blob" "assets" {
  for_each = { "app.css" = "text/css", "logo.svg" = "image/svg+xml" }

  name                 = each.key
  storage_container_id = azurerm_storage_container.assets.id
  type                 = "Block"
  source               = "${path.module}/assets/${each.key}"
  content_type         = each.value
}

output "asset_base_url" {
  value = "${azurerm_storage_account.assets.primary_blob_endpoint}${azurerm_storage_container.assets.name}"
}

# Tell the Flashcard app where its assets live. The page asks the API (/api/config),
# and the API reads this parameter. It's destroyed together with this root.
resource "aws_ssm_parameter" "assets_base_url" {
  name  = "/tf-bootcamp/dev/assets/base_url"
  type  = "String"
  value = "${azurerm_storage_account.assets.primary_blob_endpoint}${azurerm_storage_container.assets.name}"
}
```

The boot scripts `capstone/aws/templates/*.sh.tftpl` (the Flashcard Quiz) and the assets are the files in the course's `data/` folder, copied unchanged.

