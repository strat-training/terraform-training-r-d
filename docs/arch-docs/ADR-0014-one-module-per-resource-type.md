# ADR-0014: One Terraform module per resource type (network grouped)

- **Status:** Accepted
- **Date:** 2026-09-29
- **Supersedes:** the module layout in soldoc §6 (`compute/`, `traffic/`, `database/`, `observability/`, `storage/`, `security/`)
- **Modules affected:** M3, M5, M6, M7, M9, M10; the capstone (requirement 17)
- **Related:** ADR-0001, ADR-0006, ADR-0007, ADR-0013

## Context

The first course draft grouped Terraform modules by architectural layer (`compute`, `traffic`, `database`, `observability`). The course owner wants trainees to learn the structure real teams use: **one module per resource type**, reused wherever the resource repeats. The network is the accepted exception: a VPC, its subnets, gateways and route tables are always built and changed together, so they stay one module.

## Decision

1. Child modules, one per resource type:

   | Module | Wraps | Called in the capstone |
   |---|---|---|
   | `ec2-instance` | one EC2 instance | M3 prototype only |
   | `s3-bucket` | bucket + public-access block | `uploads_bucket` |
   | `network` | VPC, subnets, IGW, NAT, route tables, associations, S3 endpoint (grouped) | once |
   | `security-groups` | every tier's security group + chain rules, from one map | once |
   | `iam-instance-role` | role, inline policy (statements passed in), SSM core, instance profile | once |
   | `alb` | load balancer + target group + listener | twice: `web_alb`, `app_alb` |
   | `asg` | Launch Template + Auto Scaling group (+ optional CPU policy) | twice: `web_asg`, `app_asg` |
   | `rds-mysql` | password, secret, subnet group, parameter group, DB instance | once |
   | `sns-topic` | topic + optional email subscription | once |
   | `cloudwatch-alarm` | one metric alarm | three times |

2. **The root owns the wiring and the cross-cutting resources:**
   - the SSM `runtime_config` map, which becomes `aws_ssm_parameter.runtime` (ADR-0006);
   - the IAM policy statements passed to `iam-instance-role`, including the DB secret (ADR-0006 §5);
   - the CloudWatch dashboard.

   Modules never publish SSM parameters or attach policies to other modules' roles.
3. Module names describe **what** is created, not **which tier** it serves. The tier comes from the call's name and inputs.
4. The resource count for the full `dev` stack is **75** (mocked plan, 2026-09-29). It was 76 with the layered layout, because the separate secret-read policy is now one statement in the role's inline policy.

## Options considered

| Option | Verdict |
|---|---|
| Layered modules (`compute`, `database`, …) | Rejected — course owner decision; hides resource types and encourages "god modules". |
| Public registry modules (e.g. `terraform-aws-modules/*`) | Rejected for teaching — too many inputs for beginners, and hides what is being learned. Mentioned as a next step in real projects. |
| Split `network` into `vpc`, `subnet`, `nat-gateway`, … | Rejected — these resources change together; splitting adds wiring without benefit. |

## Consequences

- More, smaller modules. Each is easy to read and test, and `alb`/`asg`/`cloudwatch-alarm` show reuse directly.
- The root `main.tf` is longer, but it reads as the architecture diagram.
- Capstone requirement 17 ("Module structure") and the rubric's "Structure & reuse" criterion grade this layout.
