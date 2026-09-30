# Capstone Grading Rubric — 3-Tier AWS Stack with Multi-Cloud Backup & Assets

Instructor-facing. This applies the course's platform-agnostic facilitator framework
(`knowledge/patterns/technical-grading-rubric.md`) to this capstone with the
**Weighted** grading style. Use it with
`capstone-3-tier-multicloud-instructor.md`, which maps every requirement to
its solution and expected evidence.

## 1. Weights

**Tier 1 (Requirements & Architecture) is excluded.** The cohort brief (`modules/capstone-requirements.md`) already
contains both a "Project Requirements" section and an "Architecture" section, so planning was not the trainee's own work. The
renormalized weights apply:

| Phase | What you are grading | Weight |
|---|---|---|
| **Technical Execution** | Implementation quality, configuration standards, security practices and tool use as taught in M1–M12 | **45%** |
| **Functional Demonstration** | A live walkthrough of every happy path and failure path, ending in a clean teardown | **35%** |
| **Presentation & Defense** | Explaining choices, defending trade-offs, handling a live anomaly | **20%** |

On top of the weighted score, the pass/fail **Technical Documentation Gate** (§3) applies.

## 2. Scoring method

Each phase has several criteria, and each criterion is scored **1–4**. Phase score =
mean of its criteria ÷ 4 × phase weight. The final score is the sum of the three phases.

| Band | Final score | Meaning |
|---|---|---|
| Exemplary | ≥ 90% | Goes beyond the course material, with production-quality habits |
| Proficient | 70–89% | **Target.** All requirements met, with clean, secure code |
| Developing | 50–69% | Works partially; standards are missed in several places |
| Below expectations | < 50% | Core requirements missing or not working |

**Hard caps** (applied after scoring):
- **Any committed secret** (a password, access key or private key in the repo or its history) caps Technical Execution at **1**.
- **A billable resource left running after the demo** (a non-empty `terraform state list` after destroy, or any resource created by hand outside Terraform) caps Functional Demonstration at **2**.

**Worked example.** Technical Execution criteria scored 3, 3, 4, 3 → mean 3.25 → 3.25/4 × 45 = **36.6**.
Functional Demonstration 3, 2, 3 → 2.67 → 2.67/4 × 35 = **23.3**.
Presentation & Defense 3, 3 → 3.0 → 3/4 × 20 = **15.0**.
Final = **74.9% → Proficient**, if the Documentation Gate is Met.

## 3. Technical Documentation Gate (pass/fail)

- **Source:** the trainee's `EVIDENCE.md`, as required by the Deliverables → Documentation section of `modules/capstone-requirements.md`.
- **Met** only if it contains the trainee's **real** output for:
  - every happy-path and failure-path step, with the command that produced it;
  - the seed dump's row count (5) and the GCS object listing;
  - both final `terraform destroy` summaries and an empty, timestamped `terraform state list` for each root;
  - the spend figure;
  - the four explanations in the trainee's own words (separate state root, SG statefulness, CORS is not authorization, `random_password` and encrypted state).
- **Not Met** if the file is missing, has placeholder text, or has output that doesn't match the trainee's own resources: other account IDs, other bucket suffixes, or timestamps that don't fit the commit history.
- **Not Met fails the capstone**, whatever the weighted score.

## 4. Criteria

### 4.1 Technical Execution (45%): pre-demo repository review

| Criterion | 1 — Below | 2 — Developing | 3 — Proficient | 4 — Exemplary | Req. |
|---|---|---|---|---|---|
| **State & versioning** | Local state or no locking; versions unpinned | S3 backend, but a DynamoDB table, no encryption, or no lock file committed | Bootstrap root hardened (`prevent_destroy`, versioning, SSE, public-access block); `use_lockfile`, `encrypt`; `>= 1.11.0`; exact provider pins; lock file committed | Also: partial backend config (no account ID in code); noncurrent-version expiry; `terraform test` with mocks covers the guards | 1, 14 |
| **Structure & reuse** | One flat file; copy-pasted tiers | Some modules, but grouped by layer ("compute", "data") or copied instead of reused | One module per resource type (`s3-bucket`, `security-groups`, `iam-instance-role`, `alb`, `asg`, `rds-mysql`, `sns-topic`, `cloudwatch-alarm`), `network` grouped; `alb` and `asg` reused for Web and App; `for_each` over maps; no hardcoded AMI/AZ | Clean module interfaces with descriptions and validation; `moved` blocks used where addresses changed | 4, 5, 8, 17 |
| **Security controls** | Wide-open SGs, `"*"` IAM, or plaintext secrets (cap applies) | SG chain partly uses CIDRs; IAM broader than needed | SG chain generated from one map; single commented `0.0.0.0/0` ingress; DB with no egress; IAM scoped to exact ARNs; IMDSv2; password only via `random_password` → Secrets Manager | Also: uses `manage_master_user_password` or write-only/ephemeral values to keep the password out of state, and explains the trade-off | 6, 7, 10 |
| **Cost & lifecycle hygiene** | NAT/RDS/ALBs with no guards; resources created by hand (cap applies) | Guards exist but are inconsistent; some names or tags missing | `nat_gateway_enabled` + precondition; `cpu_credits = "standard"`; RDS lab settings (no backups, `skip_final_snapshot`); tags and `<project>-<workspace>-<role>` names everywhere; everything Terraform-managed | Also: `terraform test` with mocked providers covering the guards; spend tracked in `EVIDENCE.md` | 13, 18 |

### 4.2 Functional Demonstration (35%): live

| Criterion | 1 — Below | 2 — Developing | 3 — Proficient | 4 — Exemplary | Req. |
|---|---|---|---|---|---|
| **Happy path end to end** | Stack doesn't apply, or the web URL fails | The quiz page loads, but cards, answers, the backup or the Azure assets are missing | The Flashcard Quiz works live (10 cards from RDS, the score survives a reload); `/api/health` and `/api/db` correct; the dump with cards + answers in GCS; the quiz footer shows "Azure Blob ✓"; a forced alarm emails; the dashboard is populated | Also: shows *Answered by App server* switching servers, and the quiz staying up while an App server is terminated; explains each hop | 9, 10, 12, 15, 16 |
| **Failure paths** | Failure paths not shown, or they fail for the wrong reason | Some shown; at least one fails with a generic or unexplained error | All five fail **with the expected specific error or status**: validation, precondition, blocked 3306, ASG replacement, CORS 403 | Also handles the facilitator's unrehearsed "break it" request (§5, step 2) cleanly | 2, 3, 6, 8, 16, 17 |
| **Teardown discipline** | Resources left running, or created outside Terraform (cap applies) | Destroyed, but state wasn't checked, or leftovers had to be cleaned up by hand | Both roots destroyed in reverse order; `terraform state list` empty on screen for both; nothing created outside Terraform; `bootstrap/` intact | Also shows spend well under budget and explains the ledger | 18 |

### 4.3 Presentation & Defense (20%): live

| Criterion | 1 — Below | 2 — Developing | 3 — Proficient | 4 — Exemplary |
|---|---|---|---|---|
| **Troubleshooting** | Cannot locate a problem when something breaks | Finds it only with heavy prompting; relies on re-running without understanding | Reads the plan or error, names the responsible resource or module, and fixes or explains it | Diagnoses quickly using state, plan and AWS CLI evidence; predicts the blast radius of the fix |
| **Explaining trade-offs** | Cannot say why the design looks the way it does | Repeats course statements without reasoning | Explains the single NAT, single-AZ RDS, prod plan-only, SSM runtime config and the separate multicloud root as deliberate cost or safety choices | Compares alternatives (NAT instance, Multi-AZ, OIDC vs. keys, managed master password) with costs and failure modes |

## 5. Facilitator process

### Step 1: Pre-demo review (grade Technical Execution here)
Before the session, in the trainee's repository:
- **Commit history:** incremental commits across the four weeks, not one dump.
- **Secret scan:**
  ```bash
  git log -p | grep -Ei 'password *=|aws_secret_access_key|BEGIN .*PRIVATE KEY'
  ```
  It should return nothing except `random_password` references.
- **Static checks,** in each of `bootstrap/`, `capstone/aws/` and `capstone/multicloud/`:
  ```bash
  terraform fmt -check -recursive
  terraform init -backend=false
  terraform validate
  ```
- **Wide-open rules:**
  ```bash
  grep -rn '0.0.0.0/0' --include=*.tf .
  ```
  Only the Web ALB ingress and the commented egress lines should appear.
- **Wildcard IAM:**
  ```bash
  grep -rn '"\*"' --include=*.tf .
  ```
  Only CORS `allowed_headers` should appear. There must be none in IAM documents.
- **Module layout:** confirm one module per resource type under `modules/` (network grouped), and that `alb` and `asg` are each called twice rather than copied.
- **`EVIDENCE.md`:** decide the Documentation Gate.

### Step 2: Live "destructive" test (part of Functional Demonstration)
Don't let the trainee run only a rehearsed script. Pick **at least two**:

| Ask the trainee to… | A correct response |
|---|---|
| Plan with `-var environment=qa` | Stops at validation, with their own message |
| `terraform workspace select default` and plan | Precondition error naming the workspace |
| Plan with `-var nat_gateway_enabled=false` | NAT guard precondition fails; they explain the App bootstrap would hang |
| Terminate an App instance | New instance launched; target group back to healthy |
| Change the CORS `allowed_origins` to another host and re-apply | The ALB origin's preflight now returns 403 |
| Add a tier `cache` on port 6379 from `app` | One map entry; the plan shows exactly one new SG and its rules |

### Step 3: The "why" Q&A (final 5 minutes; Presentation & Defense)
- "Why does the state bucket live in its own root that you never destroy?"
- "Your DB security group has no egress rule. How do query results get back to the App tier?"
- "`random_password` keeps the password out of your code. Where is it still, and how do you protect it?"
- "Why is prod plan-only, and what would you change first to make it production-grade, and at what cost?"
- "If traffic grew 100× tomorrow, what breaks first in this design?" (Expected: the single NAT, single-AZ RDS and `t3.micro` sizing; the App ASG max of 4.)
- "What was the hardest bug you hit, and how did you find it?"

## 6. Score sheet

| Phase | Criterion | Score (1–4) | Notes |
|---|---|---|---|
| Technical Execution (45%) | State & versioning | | |
| | Structure & reuse | | |
| | Security controls | | |
| | Cost & lifecycle hygiene | | |
| Functional Demonstration (35%) | Happy path end to end | | |
| | Failure paths | | |
| | Teardown discipline | | |
| Presentation & Defense (20%) | Troubleshooting | | |
| | Explaining trade-offs | | |
| **Caps applied** | | | |
| **Documentation Gate** | Met / Not Met | | |
| **Final** | % and band | | |
