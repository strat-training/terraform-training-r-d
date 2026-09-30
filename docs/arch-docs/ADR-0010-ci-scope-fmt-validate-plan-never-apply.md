# ADR-0010: CI/CD scope — fmt, validate, plan, PR comment; never apply

- **Status:** Superseded by [ADR-0013](ADR-0013-cicd-out-of-scope.md) (2026-09-29): CI/CD is out of scope for the bootcamp. (Earlier partly superseded by ADR-0011.)
- **Date:** 2026-09-28
- **Modules affected:** M17 (and it validates M1–M16 code)
- **Related:** ADR-0002, ADR-0003, ADR-0009

## Context

M17 builds a GitHub Actions workflow that runs `terraform fmt`, `validate` and `plan` on every pull request and (challenge) posts the plan as a PR comment. The lecture covers security in automation. Running `apply` in CI would create billable infrastructure with nobody watching, which conflicts with the apply-window model (ADR-0003). Cloud credentials in CI are also a risk.

## Decision

1. Trigger: `pull_request` only. `concurrency` cancels superseded runs.
2. **Job `static` (no credentials, no cloud calls):** `terraform fmt -check -recursive`; for each root (`bootstrap`, `capstone/aws`, `capstone/multicloud`) run `terraform init -backend=false` then `terraform validate`. Cost: nothing but runner minutes.
3. **Job `plan` (needs `static`):** `terraform plan -no-color -lock=false` for `capstone/aws` in the **dev** workspace.
   - `-lock=false` means the CI identity needs only read access to state, not the ability to write lock objects.
   - Against a torn-down stack the plan shows "create everything" — expected, and free.
   - `multicloud` gets `validate` only in CI unless GCP/Azure credentials are supplied; planning it is optional.
4. **PR comment (challenge):** `actions/github-script` posts the plan as a collapsible markdown block; output is truncated to stay under GitHub's comment size limit, with a link to the run log for the full text. Workflow `permissions:` grant only `contents: read` and `pull-requests: write`.
5. **No `apply` job exists.** Applies are manual, local, and followed by teardown (ADR-0003).
6. **Credentials:** prefer GitHub OIDC to assume a **read-only plan role** in the sandbox; if OIDC cannot be set up in the sandbox, use repository secrets holding a read-only credential. Never commit credentials; do not expose secrets to fork PRs (the `plan` job is skipped for forks).
7. Pin third-party actions to a full version or commit SHA; cache the provider plugin directory to shorten runs.

## Options considered

| Option | Verdict |
|---|---|
| Apply on merge to `main` | Rejected — creates unattended billable infrastructure; contradicts session teardown. |
| Plan-only with cloud credentials but full lock | Rejected — requires write permission to the state bucket for a read-only job. |
| Static checks only | Rejected — the PRD requires `plan` on each PR. |
| Policy-as-code (OPA/Sentinel) | Out of scope per PRD. |
| Paid scanners / Infracost SaaS | Out of scope per PRD. |

## Consequences

- CI adds no cloud cost: GitHub Actions minutes are free for public repositories and covered by a monthly allowance on private repositories (verify the current allowance); each run is a couple of minutes.
- `plan` failures caused by missing credentials on fork PRs are expected and documented.
- Learners see the full loop (format → validate → plan → review) without ever creating resources from CI.
