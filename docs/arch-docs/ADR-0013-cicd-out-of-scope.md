# ADR-0013: CI/CD is out of scope for the Terraform bootcamp

- **Status:** Accepted
- **Date:** 2026-09-29
- **Supersedes:** ADR-0010 and ADR-0011 in full; the PRD's Module 17 (Multi-Cloud CI/CD Pipeline)
- **Modules affected:** the former M17; `bootstrap/` (the CI identity); the capstone (the old requirement 17)
- **Related:** ADR-0002, ADR-0012, ADR-0014

## Context

The PRD ends with a CI/CD module: GitHub Actions in the PRD, then GitLab CI in ADR-0011. The course owner has decided that pipeline automation is a separate discipline, outside the scope of a **Terraform** bootcamp. The four weeks are better spent on Terraform itself: state, modules, environments, and a full deployment.

## Decision

1. Remove the CI/CD module. The course has 12 modules (soldoc §12 mapping). The last two cover GCP (M11) and Azure (M12) separately.
2. Remove `bootstrap/ci.tf` (the GitLab OIDC provider and plan role), and `.gitlab-ci.yml`, from the course and the reference solution.
3. Capstone requirement 17 ("Pipeline") is replaced by **"Module structure"** (ADR-0014). The other requirement numbers are unchanged.
4. Remove the pipeline items from the rubric (the pipeline review step, and the "`apply` in CI" cap). The format check stays a local habit: `terraform fmt -check -recursive` and `terraform validate` appear in M10's pre-flight.
5. Keep the research on GitLab OIDC and the MR widget (references file, ADR-0011) as author background, for a possible follow-on course.

## Options considered

| Option | Verdict |
|---|---|
| Keep GitLab CI (ADR-0011) | Rejected — course owner decision: out of scope for a Terraform bootcamp. |
| Keep a minimal "fmt + validate" pipeline | Rejected — still needs a CI platform account and setup; the same checks run locally in M10. |

## Consequences

- One less platform (GitLab) for trainees to set up, and no CI identity in `bootstrap/`.
- The PRD, ADR-0010 and ADR-0011 no longer describe the delivered course; they stay as history.
- Trainees who want pipeline automation need a separate course. The capstone still teaches `plan`-before-`apply` discipline and local checks.
