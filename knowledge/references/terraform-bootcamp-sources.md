# Research Sources — 4-Week Terraform Bootcamp

Author-only reference list. Every URL below was fetched on **2026-09-28**
and returned HTTP 200 at the address shown. Where the original address redirected,
the final address is listed. Module files (`modules/*.md`) may cite **only**
URLs from this file in their Supplemental Reading sections. Add a URL here
first, with its verification date, before citing it anywhere else.

Registry pages (`registry.terraform.io`) return HTTP 200 for any path, so
each registry slug below was also checked against the registry API
(`/v1/providers/hashicorp/<name>/<version>`) for the pinned provider version.

## Pinned tool and provider versions (resolved 2026-09-28)

| Item | Version | How resolved |
|---|---|---|
| Terraform CLI (author machine) | 1.16.3 | `terraform version` |
| Minimum `required_version` | `>= 1.11.0` | S3 native locking (`use_lockfile`) is GA from 1.11 (soldoc §6, ADR-0002) |
| `hashicorp/aws` | 6.66.0 | `resolve_package_versions` (terraform) |
| `hashicorp/random` | 3.9.1 | `resolve_package_versions` (terraform) |
| `hashicorp/google` | 8.4.0 | `resolve_package_versions` (terraform) |
| `hashicorp/azurerm` | 5.7.0 | `resolve_package_versions` (terraform) |
| Demo app: Node.js | v24.21.0 LTS (Krypton), tarball SHA-256 `fd8e59d5a511510f6a298afb548f18c7d2b1be404d8b4a27d94fbe49f56cb2d6` | nodejs.org/dist/index.json + SHASUMS256.txt, 2026-09-29 |
| Demo app: `mysql2` (npm) | 3.24.4 | `resolve_package_versions` (npm), 2026-09-29 |
| Demo app: React / ReactDOM UMD | 18.3.1 (last line with UMD builds), SRI `sha384-DGyLxAyjq0f9SPpVevD6IgztCFlnMF6oW/XQGmfe+IsZ8TqEiDrcHkMLKI6fiB/Z` / `sha384-gTGxhz21lVGYNMcdJOyq01Edg0jhn/c22nsx0kyqP0TxaV5WVdsSH1fSDUf5YJj1` | jsDelivr, fetched and hashed 2026-09-29 |
| CI image `hashicorp/terraform` *(CI now out of scope, ADR-0013)* | 1.16.3 @ `sha256:c9a9d991c113f3bda5269de1506983d45ce1409dfe702df433acf10a5ea9f6bc` (Alpine 3.24; `apk add jq` → jq 1.8.2) | Docker Hub API tag digest; image pulled and tested 2026-09-29 |

**What validation found (and fixed in the course code):** in azurerm 5.x,
`azurerm_storage_blob` takes `storage_container_id`. The old
`storage_account_name`/`storage_container_name` pair is gone.
`terraform validate` rejected the 4.x form.

## Facts checked against sources (used in module text)

| Fact | Source |
|---|---|
| DynamoDB-based locking for the S3 backend is deprecated; `use_lockfile` needs `s3:GetObject`/`PutObject`/`DeleteObject` on the `.tflock` key; `encrypt` covers state and lock files | [S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3) |
| RDS for MySQL 8.0 end of standard support 31 July 2026, Extended Support pricing from 1 Aug 2026; MySQL 8.4 end of standard support 31 July 2029 | [MySQL on Amazon RDS versions](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/MySQL.Concepts.VersionMgmt.html) |
| GCS minimum storage durations: Standard none, Nearline 30 d, Coldline 90 d, Archive 365 d | [GCS storage classes](https://docs.cloud.google.com/storage/docs/storage-classes) |
| CloudWatch free tier: 3 custom dashboards (≤ 50 metrics each), 10 standard alarm metrics; $0.10 per standard alarm metric per month beyond that | [CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/) |
| Azure Storage CORS is set per service (Blob/File/Queue/Table), up to 5 rules per service; "CORS is not an authorization mechanism"; unmatched preflight → 403 | [CORS support for Azure Storage](https://learn.microsoft.com/en-us/rest/api/storageservices/cross-origin-resource-sharing--cors--support-for-the-azure-storage-services) |
| Associating a **new** DB parameter group applies its static *and* dynamic parameters only after a reboot; later edits to dynamic parameters in an already-associated group apply immediately. (This corrects ADR-0005 §7's "no reboot for dynamic parameters".) | [Associating a DB parameter group](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithParamGroups.Associating.html) |
| Ubuntu 22.04 (jammy) AMIs: owner `099720109477`, name pattern `ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*`, SSM path `/aws/service/canonical/ubuntu/server/jammy/stable/current/amd64/hvm/ebs-gp2/ami-id` | [Find Ubuntu images on AWS](https://ubuntu.com/aws/docs/aws-how-to/instances/find-ubuntu-images/) |

## Sources by module

### Cross-cutting
- [What is Terraform?](https://developer.hashicorp.com/terraform/intro)
- [Terraform language overview](https://developer.hashicorp.com/terraform/language)
- [Terraform style guide](https://developer.hashicorp.com/terraform/language/style)
- [AWS provider documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS provider: resource tagging guide (`default_tags`)](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/resource-tagging)
- [Terraform tests](https://developer.hashicorp.com/terraform/language/tests)
- [Terraform tests: mocks](https://developer.hashicorp.com/terraform/language/tests/mocking)

### M1 — Hello Terraform & Local State
- [Install Terraform](https://developer.hashicorp.com/terraform/install) · [Install or update the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) · [Configuring settings for the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html) *(fetched 2026-09-30)*
- [What is IaC? (AWS)](https://aws.amazon.com/what-is/iac/)
- [Infrastructure as code (AWS DevOps whitepaper)](https://docs.aws.amazon.com/whitepapers/latest/introduction-devops-aws/infrastructure-as-code.html)
- [Configuration syntax](https://developer.hashicorp.com/terraform/language/syntax/configuration)
- [`terraform init`](https://developer.hashicorp.com/terraform/cli/commands/init) · [`plan`](https://developer.hashicorp.com/terraform/cli/commands/plan) · [`apply`](https://developer.hashicorp.com/terraform/cli/commands/apply) · [`destroy`](https://developer.hashicorp.com/terraform/cli/commands/destroy)
- [State](https://developer.hashicorp.com/terraform/language/state)
- [Get started — AWS tutorial](https://developer.hashicorp.com/terraform/tutorials/aws-get-started)
- [`aws_instance`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) · [`aws_ebs_volume`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) · [`aws_volume_attachment`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/volume_attachment)
- [Find Ubuntu images on AWS](https://ubuntu.com/aws/docs/aws-how-to/instances/find-ubuntu-images/)

### M2 — Parameterization & Remote State
- [Input variables](https://developer.hashicorp.com/terraform/language/values/variables) · [Outputs](https://developer.hashicorp.com/terraform/language/values/outputs) · [Locals](https://developer.hashicorp.com/terraform/language/values/locals)
- [Validate configuration (validation, preconditions, checks)](https://developer.hashicorp.com/terraform/language/validate)
- [S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3)
- [`lifecycle` meta-argument (`prevent_destroy`)](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)

### M3 — Data Sources & Dependencies
- [Data sources](https://developer.hashicorp.com/terraform/language/data-sources)
- [`depends_on`](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on)
- [Resource graph](https://developer.hashicorp.com/terraform/internals/graph)
- [`aws_ami` data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) · [`aws_availability_zones`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) · [`aws_eip`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip)

### M4 — Iteration & Dynamic Rules
- [`count`](https://developer.hashicorp.com/terraform/language/meta-arguments/count) · [`for_each`](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)
- [Dynamic blocks](https://developer.hashicorp.com/terraform/language/expressions/dynamic-blocks)
- [`aws_security_group`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) · [`aws_vpc_security_group_ingress_rule`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule)

### M5 — Modules
- [Modules overview](https://developer.hashicorp.com/terraform/language/modules)
- [Standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
- [Build and use a local module (tutorial)](https://developer.hashicorp.com/terraform/tutorials/modules/module)
- [`aws_s3_bucket`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)

### M6 — VPC Topology
- [How Amazon VPC works](https://docs.aws.amazon.com/vpc/latest/userguide/how-it-works.html)
- [Subnets](https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html) · [Internet gateways](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html) · [NAT gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html) · [Route tables](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)
- [Gateway endpoints for S3](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html)
- [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/)
- [`aws_vpc`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) · [`aws_subnet`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) · [`aws_nat_gateway`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) · [`aws_route_table_association`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association)

### M7 — Security Groups & IAM
- [IAM security best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [IAM roles for EC2 / instance profiles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html)
- [Security groups](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html) · [Network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)
- [SSM Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [`aws_iam_role`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) · [`aws_iam_instance_profile`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) · [`aws_iam_policy_document`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)

### M8 — Launch Templates & Auto Scaling
- [Launch templates](https://docs.aws.amazon.com/autoscaling/ec2/userguide/launch-templates.html) · [Auto Scaling groups](https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-groups.html) · [Target tracking](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-target-tracking.html)
- [EC2 user data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)
- [Burstable instances — standard mode](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-performance-instances-standard-mode.html)
- [`aws_launch_template`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) · [`aws_autoscaling_group`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) · [`aws_autoscaling_policy`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy)

### M9 — Application Load Balancers
- [What is an Application Load Balancer?](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)
- [Target groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html) · [Health checks](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html) · [Listeners](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html)
- [`aws_lb`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) · [`aws_lb_target_group`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) · [`aws_lb_listener`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener)

### M10 — RDS & Secrets
- [Multi-AZ deployments](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html)
- [DB instances in a VPC (subnet groups)](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html)
- [Parameter groups](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithParamGroups.html) · [Associating a DB parameter group](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithParamGroups.Associating.html)
- [MySQL database log files (slow query log)](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_LogAccess.Concepts.MySQL.html)
- [MySQL on Amazon RDS versions](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/MySQL.Concepts.VersionMgmt.html) · [RDS Extended Support](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/extended-support.html)
- [RDS + Secrets Manager (managed master password)](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html) · [What is Secrets Manager?](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html)
- [Manage sensitive data in Terraform](https://developer.hashicorp.com/terraform/language/manage-sensitive-data) · [Ephemeral values](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/ephemeral)
- [`random_password`](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) · [`aws_db_instance`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) · [`aws_db_parameter_group`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) · [`aws_secretsmanager_secret`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)

### M11 — Workspaces
- [Workspaces (state)](https://developer.hashicorp.com/terraform/language/state/workspaces) · [Workspaces (CLI)](https://developer.hashicorp.com/terraform/cli/workspaces) · [`terraform workspace`](https://developer.hashicorp.com/terraform/cli/commands/workspace)
- [Conditional expressions](https://developer.hashicorp.com/terraform/language/expressions/conditionals)

### M12 — Alarms & SNS
- [CloudWatch alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html) · [Metrics](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/working_with_metrics.html)
- [What is Amazon SNS?](https://docs.aws.amazon.com/sns/latest/dg/welcome.html)
- [ALB CloudWatch metrics](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html) · [RDS CloudWatch metrics](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-metrics.html)
- [`aws_cloudwatch_metric_alarm`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) · [`aws_sns_topic`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) · [`aws_sns_topic_subscription`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription)

### M13 — Dashboards & Budgets
- [What is FinOps?](https://www.finops.org/introduction/what-is-finops/)
- [Cost Optimization pillar](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html)
- [Tagging best practices (whitepaper)](https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/tagging-best-practices.html)
- [Managing costs with AWS Budgets](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html)
- [CloudWatch dashboards](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Dashboards.html) · [Dashboard body structure](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Dashboard-Body-Structure.html)
- [CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/)
- [`jsonencode`](https://developer.hashicorp.com/terraform/language/functions/jsonencode)
- [`aws_budgets_budget`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) · [`aws_cloudwatch_dashboard`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard)

### M14 — Multi-Cloud Providers
- [Provider block (configuration, aliases)](https://developer.hashicorp.com/terraform/language/block/provider)
- [Google provider configuration reference](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference)
- [Application Default Credentials (GCP)](https://docs.cloud.google.com/docs/authentication/application-default-credentials)
- [AzureRM provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) · [Authenticating with the Azure CLI](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli)

### M15 — GCS Backup Storage
- [Storage classes](https://docs.cloud.google.com/storage/docs/storage-classes) · [Object Lifecycle Management](https://docs.cloud.google.com/storage/docs/lifecycle)
- [Uniform bucket-level access](https://docs.cloud.google.com/storage/docs/uniform-bucket-level-access) · [Public access prevention](https://docs.cloud.google.com/storage/docs/public-access-prevention)
- [`google_storage_bucket`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket)

### M16 — Azure Blob Static Assets
- [Azure Resource Manager overview](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/overview)
- [Storage account overview](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview) · [Introduction to Blob storage](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction)
- [Configure anonymous read access](https://learn.microsoft.com/en-us/azure/storage/blobs/anonymous-read-access-configure)
- [CORS support for Azure Storage](https://learn.microsoft.com/en-us/rest/api/storageservices/cross-origin-resource-sharing--cors--support-for-the-azure-storage-services)
- [CORS (MDN)](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS)
- [`azurerm_storage_account`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) · [`azurerm_storage_container`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) · [`azurerm_storage_blob`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_blob)

### M17 — CI/CD
- [Running Terraform in automation](https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform)
- [`terraform fmt`](https://developer.hashicorp.com/terraform/cli/commands/fmt) · [`terraform validate`](https://developer.hashicorp.com/terraform/cli/commands/validate)
- [CI/CD YAML syntax reference (GitLab)](https://docs.gitlab.com/ci/yaml/) · [Merge request pipelines](https://docs.gitlab.com/ci/pipelines/merge_request_pipelines/) · [CI/CD variables](https://docs.gitlab.com/ci/variables/)
- [OpenID Connect with AWS (GitLab)](https://docs.gitlab.com/ci/cloud_services/aws/) · [OIDC authentication using ID tokens](https://docs.gitlab.com/ci/secrets/id_token_authentication/)
- [Terraform/OpenTofu reports in merge requests (GitLab)](https://docs.gitlab.com/user/infrastructure/iac/mr_integration/) · [Artifacts reports](https://docs.gitlab.com/ci/yaml/artifacts_reports/)
- [Create an OIDC identity provider in IAM (AWS)](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [`hashicorp/terraform` container image](https://hub.docker.com/r/hashicorp/terraform)
- *(Verified 2026-09-29, all HTTP 200.)* GitLab facts used: `sub` = `project_path:{group}/{project}:ref_type:{type}:ref:{branch}` (the MR source branch for MR pipelines), `iss` = `https://gitlab.com`, default `aud` = the instance URL; the MR widget expects `{"create","update","delete"}` produced with `jq` from `terraform show -json`, and is not deprecated. The AWS provider and the S3 backend both read `AWS_ROLE_ARN` + `AWS_WEB_IDENTITY_TOKEN_FILE`.

## Known gaps (no dedicated source found)

- **Declarative vs. imperative** (M1 lecture): no dedicated vendor page; covered
  partially by the AWS IaC pages above. Module text says so.
- **Zero-trust security-group chaining** (M7): AWS documents security-group
  referencing, but has no page for the "chain" pattern as named here. The course
  pattern is built from the security-groups page.
- **Multi-cloud strategy (DR vs. best-of-breed)** (M14): no vendor-neutral source
  was gathered. Module text flags this with a `**Note:**`.
