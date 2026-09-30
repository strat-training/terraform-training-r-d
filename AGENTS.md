# AGENTS.md — Terraform Bootcamp course repository

## What this repository is
Course content for a **4-week, self-paced, text-based Terraform bootcamp**
(12 modules, M1–M12). Trainees build one progressive capstone: a 3-tier AWS
stack in `ap-southeast-1`, plus a GCP backup bucket and an Azure static-asset
container, all managed by Terraform. CI/CD is out of scope (ADR-0013). Hard
budget: **< $5 per learner across all three clouds**.

This repo holds **content**, not a runnable Terraform project. The Terraform
shown in the modules is validated against pinned providers, but the
course's reference solution lives in the module text and the capstone
instructor document.

## Source of truth, in priority order
1. `docs/arch-docs/ADR-0001`–`ADR-0010` and `docs/arch-docs/soldoc.md`, the
   solution design. Where these differ from the PRD, they win (for example
   single-AZ MySQL 8.4 instead of the PRD's Multi-AZ; the ADR-0007 SG chain).
2. `terraform_bootcamp_curriculum.md`, the original PRD (module list,
   guided activities, challenges, out-of-scope list).
3. `knowledge/rules/coding-standards.md`, which every code sample must follow.
4. `knowledge/references/terraform-bootcamp-sources.md`, the only allowed
   source of Supplemental Reading links and version pins.

## Layout
```text
README.md                trainee-facing entry point (mentions only modules/ and data/)
modules/                 trainee-facing: one pack per module M1–M12 (NN-<slug>.md), capstone-requirements.md (the capstone, cohort version)
data/                    trainee-facing reference data for the capstone (seed SQL, dump helper, assets, CORS probe, bad.tfvars)
capstone/                instructor-only: capstone solution (instructor version) and grading rubric
knowledge/patterns/      templates: module-content-structure, capstone-documentation-template, technical-grading-rubric
knowledge/rules/         coding standards, arch summary
knowledge/references/    researched, verified URLs + pinned versions
docs/arch-docs/          solution design + ADRs (author-only)
```

## Authoring rules
- Module files (one per module, `NN-<slug>.md`, header `# Week N — <Topic> (M<n>)`) follow `knowledge/patterns/module-content-structure.md` exactly:
  Objective → Topics → one `## M<n>` per module (Learning Objective, Core
  Idea, Why It Matters, How It Works: Concepts / Best Practices /
  Real-World Example, Supplemental Reading) → Hands-on lab (one `### M<n>`
  per module) → Lab exercise (solved practice) → Next steps (capstone tasks,
  no solution) → Checkpoint (self-assessed). Keep modules short: one small
  practice exercise, one or two easy Next steps, 3–5 checkpoint items.
- **Terraform module design taught in the course (ADR-0014):** one child module
  per resource type (`ec2-instance`, `s3-bucket`, `security-groups`,
  `iam-instance-role`, `alb`, `asg`, `rds-mysql`, `sns-topic`,
  `cloudwatch-alarm`); `network` is the one grouped module. Cross-cutting
  wiring (SSM runtime config, dashboard, IAM statements) lives in the root.
- M1 starts with **local state** and migrates it to S3 with
  `terraform init -migrate-state`; write for someone new to Terraform and show
  the expected output of every command.
- **Trainees see only `README.md`, `modules/` and `data/`.** Those files never
  name any other path (`docs/`, `knowledge/`, `capstone/`, ADR file names). Say
  "course design decision" instead. They may link to each other and to `data/`.
- Supplemental Reading uses only URLs from the references file, as inline
  `[Label](url)` links. Topics with thin sources get a `**Note:**`.
- Commands always go in fenced code blocks.
- Every hands-on lab states **apply window, estimated cost, what is left off**,
  and ends in `terraform destroy` + an empty `terraform state list`. Every
  resource in a lab is created by Terraform. Never tell trainees to create
  anything by hand in a console.
- Capstone docs come in two variants per
  `knowledge/patterns/capstone-documentation-template.md`: cohort
  (`modules/capstone-requirements.md`, the only trainee-facing capstone file; its sections follow the Stratpoint capstone-requirements format: Overview, Provided Application, Architecture, Learning Objectives, Project Requirements, Getting Started, Timeline, Evaluation Criteria, Optional Features, Deliverables, Support Resources) and instructor (`capstone/…-instructor.md`). Never merge them.
- The capstone uses the **weighted** rubric (Tier 1 excluded: 45 / 35 / 20)
  plus the pass/fail Documentation Gate.

## Security rules for samples
No plaintext secrets, no wildcard IAM resources in our own policies, no
`0.0.0.0/0` ingress except the Web ALB edge (commented), IMDSv2 on, state
encrypted with S3 native locking. Full list in `knowledge/rules/coding-standards.md`.

## Quality gates before a content change is done
- Any changed HCL passes `terraform fmt -check`, `terraform init -backend=false`
  and `terraform validate` against the pinned providers. Guards pass
  `terraform test` with mocked providers.
- Any new link is added to the references file with its fetch date first.
- Cohort and instructor capstone files still mirror each other's
  requirements one-for-one.

## Git conventions
Conventional commits (`docs(modules): …`, `docs(capstone): …`,
`chore(refs): …`). One content pack per commit where practical.
