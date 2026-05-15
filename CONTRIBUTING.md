# Contributing to sigma-platform

Solo project. The standards below exist for the solo contributor's
own discipline, not for inbound external contribution. External PRs
are not currently accepted.

## Commit conventions

[Conventional Commits](https://www.conventionalcommits.org/) format.
Allowed types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`,
`test`, `build`, `ci`, `chore`, `revert`, `infra`, `gitops`,
`policy`, `adr`.

`commitlint` enforces this in the `commit-msg` pre-commit hook.

## Branch naming

`feat/<slug>`, `fix/<slug>`, `docs/<slug>`, `infra/<slug>`,
`gitops/<slug>`, `policy/<slug>`, `adr/<slug>`.

## ADR-first design

Any "architecturally significant" decision lands an ADR in
`docs/adr/NNNN-<slug>.md` using the MADR template
(`docs/adr/0000-template.md`). Bias toward writing more ADRs, not
fewer — they are the durable artifact of this project.

## The anonymisation pledge

Every commit is treated as world-readable forever, even while the
repo is private. Before staging:

1. The `anon-scan` pre-commit hook runs `gitleaks` against the
   public `.gitleaks.toml` plus the private
   `~/.config/sigma-platform/gitleaks-forbidden.toml`.
2. If the private file is missing, the hook warns and runs
   structural rules only — anonymisation is then the contributor's
   responsibility for that commit.

If the hook ever rejects a commit, treat it as a near-miss and ask
whether the rule could have triggered later, in CI, where the
artifact would have been preserved in a workflow log. Tighten the
rule rather than allowlisting the file.

## Review

Solo project, so no review-by-peer rule. Every change still flows
through a PR for CI, but it is self-approved.
