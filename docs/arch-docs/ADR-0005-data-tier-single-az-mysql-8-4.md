# ADR-0005: Data tier — single-AZ RDS, MySQL 8.4, minimal paid features

- **Status:** Accepted; amended 2026-09-29 (decision 7 corrected)
- **Date:** 2026-09-28
- **Modules affected:** M10, M11, M12, M13
- **Related:** ADR-0003, ADR-0006, ADR-0008

## Context

The PRD specifies a **single-AZ MySQL RDS** instance (Multi-AZ is lecture-only), a random master password held in Secrets Manager, and a slow-query parameter group attached **without destructive replacement**.

Two facts shape the choices:

- **MySQL 8.0 on RDS reached end of standard support on 2026-07-31.** Instances still on 8.0 are automatically enrolled in RDS Extended Support, a paid per-vCPU-hour surcharge on top of the instance price. MySQL 8.4 (LTS) is available on RDS.
- RDS bills for instance hours, storage, backups beyond the free allowance, Performance Insights beyond the free tier, enhanced monitoring, and log exports through CloudWatch.

## Decision

1. **Engine:** `mysql`, version **8.4.x** (latest available minor), parameter-group family **`mysql8.4`**. Never 8.0.
2. **Instance class:** `db.t4g.micro` preferred, fall back to `db.t3.micro`. Confirm orderable classes for the chosen version in `ap-southeast-1` (`aws rds describe-orderable-db-instance-options`) before publishing.
3. **Topology:** `multi_az = false`, `publicly_accessible = false`, placed in the DB subnet group over the two private DB subnets.
4. **Storage:** gp3, 20 GB (RDS minimum); no storage autoscaling (`max_allocated_storage` unset); `storage_encrypted = true` with the AWS-managed key.
5. **Paid extras off:** `backup_retention_period = 0`, `skip_final_snapshot = true`, `performance_insights_enabled = false`, `monitoring_interval = 0`, `enabled_cloudwatch_logs_exports = []`, `deletion_protection = false` (lab only; note it in the text).
6. **Credentials:** `random_password` → Secrets Manager secret with `recovery_window_in_days = 0`; the instance consumes the password from that resource. Note for learners: `random_password` still places the value in Terraform state, so the state bucket must stay encrypted and private (ADR-0002). RDS-managed master passwords (`manage_master_user_password`) are described in the lecture as the state-free alternative.
7. **Parameter group (M10 challenge):** `aws_db_parameter_group` with `name_prefix`, family `mysql8.4`, `slow_query_log = 1` (dynamic parameter, `apply_method = "immediate"`), optional `long_query_time`, and `lifecycle { create_before_destroy = true }`. Attaching it updates the instance in place; no replacement and no reboot for dynamic parameters. Slow-query output stays in the RDS log files (`log_output` default); it is **not** exported to CloudWatch.
8. **Sizing by workspace** (ADR-0008): dev = micro/20 GB; prod = next class up and larger storage. Prod is planned but not run except in the single final integrated run.

## Options considered

| Option | Verdict |
|---|---|
| MySQL 8.0 | Rejected — automatic paid Extended Support after 2026-07-31. |
| Aurora / Aurora Serverless | Rejected — outside the PRD's RDS MySQL scope and higher idle cost. |
| Multi-AZ | Rejected for the lab — PRD says lecture-only, doubles instance cost. |
| Automated backups on | Rejected — backup storage beyond the free allowance bills; the data is disposable. |
| Storage autoscaling | Rejected — unbounded cost potential for zero teaching value. |

## Consequences

- Destroying RDS leaves no snapshot and no cost, but also no recovery: acceptable for lab data.
- The M12 free-storage alarm (< 2 GB) works against the fixed 20 GB volume.
- The MySQL 8.4 authentication default (`caching_sha2_password`) means the demo API's MySQL client must support it; use a current driver.
- Re-verify the engine's support status each cohort.

## Amendment — 2026-09-29: parameter-group association needs one reboot

Decision 7 said attaching the parameter group needs "no reboot for dynamic parameters". AWS documents otherwise: *"When you associate a new DB parameter group with a DB instance, the modified static and dynamic parameters are applied only after the DB instance is rebooted. However, if you modify dynamic parameters in the DB parameter group after you associate it with the DB instance, these changes are applied immediately without a reboot."* ([Associating a DB parameter group](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithParamGroups.Associating.html)).

Corrected decision 7:
- Attaching the group is still an **in-place update**, never a replacement: `name_prefix` plus `create_before_destroy`.
- The instance then shows `ParameterApplyStatus = pending-reboot`. One `aws rds reboot-db-instance` (a brief outage; no data loss, same endpoint) activates the group.
- Later changes to *dynamic* parameters in the already-associated group apply immediately.
- Best practice, taught in M10: create the instance with its own parameter group from day one.
