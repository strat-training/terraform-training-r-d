# ADR-0011: CI platform — GitLab CI merge-request pipeline with OIDC to AWS

- **Status:** Superseded by [ADR-0013](ADR-0013-cicd-out-of-scope.md) (2026-09-29): CI/CD removed from the course; kept as research for a follow-on course.
- **Date:** 2026-09-29
- **Supersedes:** ADR-0010 decisions 1, 4, 6 and 7 (the GitHub Actions specifics). ADR-0010 decisions 2, 3 and 5 (the scope: fmt, validate, plan, never apply) still hold, and are restated here for the new platform.
- **Modules affected:** M17, the capstone (requirement 17), `bootstrap/`
- **Related:** ADR-0002, ADR-0003, ADR-0010, ADR-0012

## Context

The PRD and ADR-0010 put M17 on GitHub Actions: a workflow on `pull_request`, and a plan posted as a PR comment by `actions/github-script`. The course owner has decided the bootcamp uses **GitLab**. Trainees keep their repository in a GitLab project, and the pipeline must run in GitLab CI.

The ADR-0010 constraints are unchanged:
- CI must never create infrastructure;
- static checks need no credentials;
- `plan` runs with read-only access;
- fork contributions must never reach cloud credentials.

A second constraint now applies (ADR-0012): **every** resource the course uses, including the CI cloud identity, must be created by Terraform, never by hand in a console.

## Decision

1. **Pipeline file:** `.gitlab-ci.yml` at the repository root. `workflow:rules` runs pipelines only when `$CI_PIPELINE_SOURCE == "merge_request_event"`. `default: interruptible: true` lets a newer push cancel a superseded pipeline.
2. **Image:** `hashicorp/terraform:1.16.3`, pinned **by digest** (`@sha256:c9a9d991…`), with `entrypoint: [""]` so jobs get a shell. The image is Alpine; `jq` is added at runtime with `apk add --no-cache jq` where needed.
3. **Stage `static` (no credentials, no cloud calls):**
   - job `fmt`: `terraform fmt -check -recursive -diff`;
   - job `validate`: a `parallel:matrix` over `bootstrap`, `capstone/aws` and `capstone/multicloud`, each running `terraform init -backend=false` then `terraform validate`.
4. **Stage `plan` (`needs: [fmt, validate]`):** `terraform plan -no-color -lock=false` for `capstone/aws`, with `TF_WORKSPACE=dev`.
   - `-lock=false`: the CI role needs only read access to state, never lock writes.
   - Against a torn-down stack the plan shows "create everything". That's expected, and free.
   - `capstone/multicloud` is validated only; planning it would need GCP/Azure credentials in CI.
5. **Keyless AWS access through GitLab OIDC:**
   - The `plan` job declares `id_tokens: GITLAB_OIDC_TOKEN: aud: https://gitlab.com`.
   - The job writes the token to a file and exports `AWS_WEB_IDENTITY_TOKEN_FILE` and `AWS_ROLE_ARN`. The AWS provider and the S3 backend both read these variables and assume the role themselves, so no AWS CLI is needed and no keys are stored in GitLab.
   - The only CI/CD variables are `AWS_PLAN_ROLE_ARN` and `TF_STATE_BUCKET`. Neither is secret, and both are unprotected, because merge-request branches aren't protected.
6. **The CI identity is Terraform-managed in `bootstrap/ci.tf`** (persistent root, ADR-0002), toggled by `var.gitlab_project_path` (`null` = none):
   - `aws_iam_openid_connect_provider` with URL `https://gitlab.com` and client ID `https://gitlab.com`;
   - an IAM role whose trust policy requires `gitlab.com:aud = https://gitlab.com` and `gitlab.com:sub` like `project_path:<group>/<project>:ref_type:branch:ref:*`;
   - the AWS-managed `ReadOnlyAccess` policy, which also covers reading the state bucket.

   An account holds one OIDC provider per URL. If the sandbox already has one, it is brought under Terraform with an `import` block, not duplicated.
7. **Fork isolation:** the `plan` job has `rules: - if: $CI_MERGE_REQUEST_SOURCE_PROJECT_ID == $CI_PROJECT_ID`. Separately, the trust policy's `project_path` condition rejects tokens minted for any other project, including forks.
8. **Showing the plan (M17 challenge):** the plan job writes:
   - `terraform show -no-color tfplan > plan.txt`, exposed on the merge request with `artifacts:expose_as`;
   - a `{"create","update","delete"}` summary from `terraform show -json | jq …`, published as `artifacts:reports:terraform`, which GitLab renders as the Terraform widget on the merge request.

   No API token or comment bot is needed.
9. **No apply job exists.** Applies are manual and local, and every session ends in `terraform destroy` (ADR-0003, ADR-0012).

## Options considered

| Option | Verdict |
|---|---|
| Keep GitHub Actions (ADR-0010) | Rejected — course owner decision: the bootcamp standardizes on GitLab. |
| GitLab CI with AWS access keys stored as masked CI/CD variables | Rejected — long-lived secrets in CI; OIDC removes them entirely. |
| `aws sts assume-role-with-web-identity` via the AWS CLI in the job (GitLab's documented example) | Rejected — needs an image with the AWS CLI; the Terraform provider and S3 backend already support web identity through environment variables. |
| Post the plan as an MR note via the GitLab API | Not adopted — needs a project access token with `api` scope in CI; the native `artifacts:reports:terraform` widget needs no token. Kept as an optional stretch. |
| GitLab's managed Terraform state / Terraform CI templates | Rejected — state stays in the S3 backend with native locking (ADR-0002); one state model across local and CI. |
| Create the OIDC provider and role by hand in the console | Rejected — violates ADR-0012; not reproducible, and invisible to `terraform destroy`. |

## Consequences

- CI adds no cloud cost; it uses GitLab CI compute minutes only (check the namespace's current allowance).
- Trainees need a GitLab.com project, and one extra `bootstrap/` apply with `-var gitlab_project_path=…`.
- The MR widget depends on the report format documented by GitLab (verified 2026-09-29, not deprecated). Recheck it each cohort.
- The `plan` job can only be proven end to end against a live GitLab project and AWS role. The static jobs and the report filter were verified locally inside the pinned image.
