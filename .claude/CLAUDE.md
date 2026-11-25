# Global rules

## Ask before mutating remote state

I'm a Site Reliability Engineer with CLI access to critical infrastructure (kubectl, gcloud, terraform, git, helm, etc). Never run a command that changes state, remote or local — create/update/delete/deploy/push/commit/merge or anything else that mutates a resource — without asking first and getting explicit approval, even if permissions would otherwise auto-allow it. Read-only/inspection commands (status, diff, log, show, get, describe, plan, etc.) don't need to ask. When a command's effect is ambiguous, treat it as mutating and ask.

The concrete per-tool allow/ask rules (which kubectl/gcloud/terraform/helm/git subcommands are pre-approved vs. gated) live in `~/.claude/settings.json` under `permissions.allow`/`permissions.ask` — treat that as the source of truth. Those rules match by command prefix, so a command with global flags before the subcommand can slip past the pattern (e.g. `kubectl --context=prod apply ...`); apply this rule by judgment in that case too, not just when the settings-enforced prompt fires.

## Git

- No state-changing git commands unless I specifically ask.
- Never commit to `main`, `master`, or `production`.
- No `Co-Authored-By` or AI attribution in commits/PRs.
- One commit per logical change.

## Merge request titles

Prefix MR titles with `[<region>][<component>]`, then a short description.

- Region: `OR`, `EU`, `SC`, `SG`
- Component:
  - IaC changes: the infra area, e.g. `GKE`, `IAM`
  - k8s changes: the app/service, e.g. `istio`, `envoy`, `liveramp`

Examples: `[OR][GKE] Increase default node pool max size`, `[EU][istio] Bump sidecar memory limits`.
