# 🎓 4-Week Terraform Bootcamp Syllabus (3-Tier Capstone Focused)

## 📌 Curriculum Philosophy
- **Unified Progressive Capstone:** Every week builds directly toward or extends the primary **3-Tier Architecture** on AWS (React/Nginx Web Front-end, Node.js/Python App API, Multi-AZ MySQL RDS Database), ending with a multi-cloud asset backup and global distribution tier.
- **Default Deployment Region:** Primary AWS region is set to `ap-southeast-1` (Singapore) across all modules, configuration files, and examples.
- **Self-Paced and Text-Based:** All instruction is written text with no video. Learners work alone, so every module includes a written walkthrough, a checkpoint with expected results, and a reference solution.
- **Medium Effort, Capstone-Relevant Hands-On:** Effort per module is medium. Every hands-on step builds the capstone; if a module has no capstone-relevant hands-on work, it has none.
- **Guided vs. Unguided Paradigm:**
  - **Lecture Topics:** Text covers the theoretical foundation and cloud/Terraform concepts before any code is written.
  - **Guided Activity:** A written step-by-step walkthrough leads the baseline implementation for that module's layer.
  - **Unguided Capstone:** Students independently add critical production features (resiliency, failover, zero-trust security, cost optimizations) to the exact same 3-tier codebase.
- **100% Sandbox Safe:** All resources are scoped to individual accounts with zero dependence on AWS Organizations, SCPs, or billing administrator privileges.
- **Under-$5 Budget Discipline:** Each learner has less than $5 of spend available. Every module states an estimated cost and ends with a teardown step, and learners run `terraform destroy` at the end of every session. NAT Gateways, ALBs, and Multi-AZ RDS bill by the hour, so the full stack is applied only long enough to pass the module checkpoint.
- **Modern State Locking:** Remote state uses S3 native state locking, with no DynamoDB lock table. Pin `required_version` to a Terraform release that supports it (confirm the minimum version against the current Terraform docs).
- **No Badge or Certificate:** Finishing the bootcamp does not earn a badge or certificate. Challenges are strongly encouraged but not a hard gate, because each module provides a reference solution.

---

## 🚫 Out of Scope (Sandbox Environment Exclusions)

The following topics and features are intentionally **excluded** from this curriculum to ensure compatibility with restricted sandbox accounts (AWS/GCP/Azure) and avoid permission or cost issues:

1. **AWS Organizations & SCPs:** No Service Control Policies, AWS Organizations management, or organization-level billing APIs.
2. **Account-Level Billing APIs:** Excluded tools requiring root/billing account privileges (e.g., raw Cost Explorer APIs, AWS Billing Conductor).
3. **Tag-Filtered Budgets & Cost Allocation Tags:** Activating cost allocation tags needs billing-console permission that the organization controls, so budgets are account-wide instead of filtered by tag.
4. **Paid Third-Party SaaS Tools:** No external paid tools requiring external API keys or paid tiers (e.g., Infracost SaaS API integration).
5. **Policy-as-Code Engines:** OPA (Open Policy Agent) / Rego and Sentinel policy checks were excluded to focus natively on HCL validation and GitHub Actions.
6. **Complex Multi-Cloud Global Traffic Routing:** Complex cross-cloud entry points like Azure Front Door pointing directly to AWS ALBs were replaced with simpler multi-cloud storage and static asset patterns.

---

## 📅 Week 1: Fast-Track Foundations (3-Tier Components)

### Module 1: Hello Terraform & Local State
* **Lecture Topics:** Introduction to Infrastructure as Code (IaC), Terraform Architecture (Core & Providers), Declarative vs. Imperative programming, HCL syntax fundamentals, The Terraform Lifecycle (`init`, `plan`, `apply`, `destroy`), Understanding local state files (`.tfstate`).
* **Core Concepts:** Providers, `terraform init`, `plan`, `apply`, `destroy`, HCL syntax.
* **Guided Activity:** 
  1. Configure `providers.tf` for AWS using region `ap-southeast-1`.
  2. Write `main.tf` to provision a single `t3.micro` EC2 instance in Singapore representing a standalone web prototype.
  3. Inspect `terraform.tfstate` locally, run `terraform plan`, and run `terraform destroy`.
* **Unguided Capstone Challenge:** 
  * Add an `aws_ebs_volume` resource (8 GB) and attach it to the EC2 instance using an `aws_volume_attachment` block without breaking the original instance setup.

---

### Module 2: Parameterization & Remote State
* **Lecture Topics:** DRY (Don't Repeat Yourself) coding principles, Input variables vs. Local variables vs. Outputs, State management risks in team environments, Introduction to AWS S3 remote state with native state locking.
* **Core Concepts:** `variables.tf`, `outputs.tf`, `terraform.tfvars`, remote state in AWS S3 with native S3 state locking.
* **Guided Activity:**
  1. Parameterize instance types, AMI IDs, and environment names using input variables with default region set to `ap-southeast-1`.
  2. Configure a remote backend block storing state in a versioned S3 bucket in `ap-southeast-1` with native S3 state locking enabled (`use_lockfile = true`).
* **Unguided Capstone Challenge:**
  * Add variable validation rules to enforce that the 3-tier application deployment tier (`var.environment`) can only be set to `"dev"`, `"staging"`, or `"prod"`. Verify that passing an unauthorized string blocks `terraform plan`.

---

### Module 3: Dynamic Data Sources & Dependencies
* **Lecture Topics:** Hardcoding vs. Querying infrastructure, Using `data` blocks to fetch live cloud state securely, The Terraform Resource Graph, Implicit vs. Explicit dependencies (`depends_on`).
* **Core Concepts:** `data` blocks, implicit dependencies, explicit `depends_on` rules.
* **Guided Activity:**
  1. Fetch the latest official Ubuntu 22.04 LTS AMI dynamically for `ap-southeast-1` compute nodes.
  2. Provision an Elastic IP in `ap-southeast-1` and bind it to the entrypoint server using implicit referencing.
* **Unguided Capstone Challenge:**
  * Use the `aws_availability_zones` data source to dynamically select the target Availability Zones in `ap-southeast-1` (e.g., `ap-southeast-1a`, `ap-southeast-1b`) for the web server deployment rather than hardcoding AZ strings.

---

### Module 4: Dynamic Security Rules & Iteration
* **Lecture Topics:** Managing scale with meta-arguments, `count` vs. `for_each` (and why `for_each` is safer), Utilizing HCL `locals` for complex expressions, Crafting `dynamic` blocks for nested configurations like security rules.
* **Core Concepts:** `count`, `for_each`, `dynamic` blocks, `locals`.
* **Guided Activity:**
  1. Provision a cluster of web instances using `for_each` over a map of node configurations.
  2. Construct an `aws_security_group` using a `dynamic "ingress"` block to open web communication ports (`[80, 443]`).
* **Unguided Capstone Challenge:**
  * Build a local object mapping tier names (`web`, `app`, `db`) to their required open ports and allowed source IPs. Update the dynamic security group module to automatically construct rules for both the Web and App layers from a single variable map.

---

### Module 5: Modularizing the Architecture (`./modules/compute`)
* **Lecture Topics:** Module theory: Why and when to modularize, Structure of a standard Terraform module (Root vs. Child), Passing inputs and consuming outputs, Reusability patterns for enterprise architectures.
* **Core Concepts:** DRY principles, module inputs/outputs, root invocation.
* **Guided Activity:**
  1. Move the web server and security group code into a reusable `./modules/compute` directory.
  2. Call `./modules/compute` twice from the root context: once for the Web Tier and once for the App Tier.
* **Unguided Capstone Challenge:**
  * Create a local `./modules/storage` directory that provisions an S3 bucket in `ap-southeast-1` for storing application user uploads. Pass the generated S3 Bucket Name directly into the `./modules/compute` module as an environment configuration variable.

---

## 📅 Week 2: The 3-Tier Network & Compute Stack

### Module 6: 3-Tier VPC Subnet Topology
* **Lecture Topics:** AWS Networking Fundamentals 101, VPC architecture, CIDR blocks and IP math, Subnet tiers (Public vs. Private), Internet Gateways, NAT Gateways, and Route Table routing logic.
* **Core Concepts:** Custom VPCs, Public vs. Private Subnets, Internet Gateways, NAT Gateways, Route Tables.
* **Guided Activity:**
  1. Provision a custom VPC spanning 2 AZs in Singapore (`ap-southeast-1a`, `ap-southeast-1b`).
  2. Create 6 dedicated subnets: 2 Public (Web Tier), 2 Private (App Tier), and 2 Private (Database Tier).
  3. Deploy an Internet Gateway for public traffic and a single NAT Gateway for outbound application API updates.
* **Unguided Capstone Challenge:**
  * Implement route table associations using dynamic `for_each` loops to cleanly map all 6 subnets across the Web, App, and Database route tables without writing duplicate code.

---

### Module 7: Security Group Chaining & IAM Roles
* **Lecture Topics:** Principle of Least Privilege in the cloud, IAM Roles vs. Users, EC2 Instance Profiles, Network Security: Security Groups vs. NACLs, Zero-Trust Architecture through Security Group Chaining.
* **Core Concepts:** IAM Roles, Instance Profiles, Security Group Chaining (Zero-Trust intra-tier rules).
* **Guided Activity:**
  1. Create IAM roles permitting EC2 instances to read from AWS Systems Manager (SSM) Parameter Store in `ap-southeast-1`.
  2. Implement strict Security Group chaining across tiers:
     * `Web-SG`: Accepts HTTP/HTTPS from `0.0.0.0/0`.
     * `App-SG`: Accepts incoming API traffic **strictly** from `Web-SG`.
     * `DB-SG`: Accepts database queries **strictly** from `App-SG`.
* **Unguided Capstone Challenge:**
  * Lock down the `DB-SG` rules to block all egress Internet traffic (`0.0.0.0/0`) while retaining internal communication back to the `App-SG` tier.

---

### Module 8: Stateless Compute Bootstrapping & Auto Scaling
* **Lecture Topics:** Immutable infrastructure concepts, EC2 Launch Templates vs. Launch Configurations, User Data scripts for bootstrapping, Auto Scaling Group (ASG) lifecycle, Horizontal vs. Vertical scaling.
* **Core Concepts:** Launch Templates, Auto Scaling Groups (ASG), User Data bootstrapping.
* **Guided Activity:**
  1. Write a Launch Template with User Data that automatically bootstraps the App tier API service.
  2. Deploy an Auto Scaling Group in the Private App subnets across `ap-southeast-1` AZs with a capacity range of 2–4 instances.
* **Unguided Capstone Challenge:**
  1. Build the Web tier Auto Scaling Group in the Public Web subnets across `ap-southeast-1` AZs, using its own Launch Template with User Data that bootstraps the React/Nginx front end. Module 9 routes the Web ALB to this ASG.
  2. Create a dynamic target tracking scaling policy (`aws_autoscaling_policy`) attached to the App tier ASG that scales out when average CPU utilization hits 65%.

---

### Module 9: Application Load Balancing (Web & App ALBs)
* **Lecture Topics:** Load balancing concepts (Layer 4 vs Layer 7), AWS Application Load Balancers (ALBs) architecture, Target Groups, Listeners, Path-based routing, and Health Check logic.
* **Core Concepts:** ALBs, Target Groups, Listeners, Health Check routing.
* **Guided Activity:**
  1. Deploy an Internet-facing ALB in the Public Web subnets in `ap-southeast-1` routing public web traffic to the Web Tier ASG built in Module 8.
  2. Attach health check endpoints verifying web service health on `/`.
* **Unguided Capstone Challenge:**
  * Deploy a second, internal-only ALB in the Private App subnets to sit between the Web tier and App tier, routing internal API traffic on port `8080` with dedicated health checks on `/health`.

---

## 📅 Week 3: Data Tier, Scoped FinOps & Observability

### Module 10: Multi-AZ RDS Data Tier & Secrets Integration
* **Lecture Topics:** Database scaling and high availability, RDS Multi-AZ failover architecture, DB Subnet Groups, Secrets Management in IaC (avoiding plaintext passwords in state), using the Terraform `random` provider.
* **Core Concepts:** Database Subnet Groups, Multi-AZ RDS Instances, AWS Secrets Manager.
* **Guided Activity:**
  1. Generate a database master password using `random_password` and store it in AWS Secrets Manager in `ap-southeast-1`.
  2. Provision a Multi-AZ MySQL RDS instance inside the Private Database subnets across `ap-southeast-1` AZs using the stored secret.
* **Unguided Capstone Challenge:**
  * Provision a custom `aws_db_parameter_group` enabling slow query logging (`slow_query_log = 1`) and attach it to the 3-tier RDS instance without causing an immediate destructive database replacement.

---

### Module 11: Multi-Environment Isolation via Workspaces
* **Lecture Topics:** Strategies for managing Dev/Staging/Prod environments, `terraform workspace` CLI commands, Conditional logic and ternary operators in HCL (`condition ? true : false`), Cost optimization across non-prod environments.
* **Core Concepts:** `terraform workspace`, environment-driven scaling logic.
* **Guided Activity:**
  1. Instantiate `dev` and `prod` workspaces using `terraform workspace`.
  2. Parameterize instance sizes and ASG node counts dynamically based on `terraform.workspace`.
* **Unguided Capstone Challenge:**
  * Write conditional execution logic so that the `dev` workspace provisions a single NAT Gateway in 1 AZ (`ap-southeast-1a`) to save costs, while the `prod` workspace provisions dual NAT Gateways across 2 AZs for full fault tolerance.

---

### Module 12: 3-Tier Metric Alarms & SNS Alerting
* **Lecture Topics:** Cloud observability principles, Amazon CloudWatch Metrics vs. Logs, CloudWatch Alarms, Simple Notification Service (SNS) pub/sub model, Integrating infrastructure with alerting systems.
* **Core Concepts:** CloudWatch Alarms, SNS Topics, Subscriber Notifications.
* **Guided Activity:**
  1. Create an SNS topic in `ap-southeast-1` for infrastructure operational alerts.
  2. Configure CloudWatch Metric Alarms monitoring App Tier ASG CPU utilization (greater than 80%) and Web ALB 5xx error responses.
* **Unguided Capstone Challenge:**
  * Add a CloudWatch Metric Alarm tracking RDS Free Storage Space, sending an alert through SNS when available database storage drops below 2 GB.

---

### Module 13: Capstone Cost Dashboards & Budgets
* **Lecture Topics:** FinOps 101: Understanding cloud costs, Tagging strategies for resource ownership and cleanup, AWS Budgets vs. Cost Explorer, Building automated CloudWatch Dashboards using Terraform JSON encoding.
* **Core Concepts:** `aws_cloudwatch_dashboard`, account-wide `aws_budgets_budget`.
* **Guided Activity:**
  1. Construct a unified CloudWatch Dashboard rendering CPU utilization, active ALB requests, and RDS database connections for the `ap-southeast-1` 3-tier stack.
  2. Create an account-wide AWS Budget capped at $5 USD/month. Tag-filtered budgets are out of scope.
* **Unguided Capstone Challenge:**
  * Extend the budget policy to send a warning alert when **forecasted** spend is projected to breach 100% of the monthly budget threshold.

---

## 📅 Week 4: Multi-Cloud Integration & Automation

### Module 14: Multi-Cloud Provider Setup
* **Lecture Topics:** Multi-cloud strategies and use cases (Disaster Recovery vs. Best-of-Breed), Configuring multiple Terraform providers in one project, Provider aliases, Authenticating securely to GCP and Azure from a local environment.
* **Core Concepts:** Multi-provider declarations (`aws`, `google`, `azurerm`), environment credentials.
* **Guided Activity:**
  1. Configure `providers.tf` to authenticate concurrently with AWS (`region = "ap-southeast-1"`), GCP (`region = "asia-southeast1"`), and Azure (`location = "Southeast Asia"`) using sandbox environment variables.
  2. Initialize provider plugins using `terraform init`.
* **Unguided Capstone Challenge:**
  * Define localized input variables for each provider's target deployment region (`aws_region = "ap-southeast-1"`, `gcp_region = "asia-southeast1"`, `azure_location = "Southeast Asia"`) with customized default values.

---

### Module 15: Cross-Cloud Database Backup Storage (GCP)
* **Lecture Topics:** GCP Object Storage fundamentals (GCS) vs. AWS S3, Cross-cloud data transfer patterns, IAM bucket bindings in GCP, Storage lifecycle policies (Standard vs. Nearline vs. Coldline).
* **Core Concepts:** `google_storage_bucket`, lifecycle management, cross-cloud backup architecture.
* **Guided Activity:**
  1. Deploy a Google Cloud Storage (GCS) bucket in `asia-southeast1` (Singapore) using the GCP provider to serve as off-site backup storage for AWS RDS database dumps from `ap-southeast-1`.
* **Unguided Capstone Challenge:**
  * Implement lifecycle rules on the GCS bucket to automatically transition database dumps older than 30 days to Coldline storage to minimize backup costs.

---

### Module 16: Multi-Cloud Static Asset Distribution (Azure)
* **Lecture Topics:** Azure Resource Manager (ARM) vs. AWS Resource Model, Azure Resource Groups, Azure Blob Storage concepts, Offloading compute via static asset hosting, Cross-Origin Resource Sharing (CORS) principles, including why Azure applies CORS rules at the storage account's blob service rather than on a container.
* **Core Concepts:** `azurerm_resource_group`, `azurerm_storage_account`, `azurerm_storage_container`, blob service CORS rules.
* **Guided Activity:**
  1. Deploy an Azure Storage Account and Blob Container in `Southeast Asia` (Singapore) to host public frontend static assets (images, CSS, JS) offloading traffic from the AWS Web Tier.
* **Unguided Capstone Challenge:**
  * Configure CORS (Cross-Origin Resource Sharing) rules on the Azure Storage Account's blob service (the `cors_rule` block under `blob_properties`) so that JavaScript running in the browser, on pages served by the AWS Web Tier through the Web ALB in `ap-southeast-1`, can fetch media assets from the Blob Container without cross-site errors. Set the allowed origin to the Web ALB's address.

---

### Module 17: Multi-Cloud CI/CD Pipeline
* **Lecture Topics:** GitOps and Infrastructure as Code automation, CI/CD pipeline philosophy, GitHub Actions fundamentals (Workflows, Jobs, Steps), Using Terraform CLI tools in CI (`fmt`, `validate`, `plan`), Security in automation.
* **Core Concepts:** GitHub Actions workflows, `terraform fmt`, `terraform validate`, automated PR plans.
* **Guided Activity:**
  1. Build a `.github/workflows/terraform.yml` pipeline that runs formatting checks, validation, and `terraform plan` on every Pull Request.
* **Unguided Capstone Challenge:**
  * Extend the workflow to extract the generated `terraform plan` output and post it as a markdown summary comment on the GitHub Pull Request.