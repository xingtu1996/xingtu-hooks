# AGENTS.md — xingtu-hooks

## Repository role
This repository contains installable Agent hooks and mechanical guardrails.

## Source of truth
Start with `README.md`, then inspect `hooks/` and any more specific instructions in the directory being changed. The current code and tests take precedence over unverified README examples.

## Project-specific guardrails
Review base/dev/content hook scope before editing. Test deny/allow cases including destructive commands and secret handling. Never weaken protections merely to pass a test; avoid executing destructive examples against real data.

## Shared capabilities
Reusable Skills live in [xingtu-skills](https://github.com/xingtu1996/xingtu-skills), while shared rules, hooks and SDD assets are maintained in their respective repositories. A link to another repository is **not** automatic instruction inheritance or skill installation. Verify compatibility and use an explicit, reviewable install/version mechanism before invoking shared assets.

## Change protocol
1. Inspect existing repository instructions, source and relevant tests.
2. For nontrivial work, write or update an SDD spec with acceptance criteria before implementation.
3. Work on an isolated branch and open a reviewable PR. Do not change visibility, licenses, secrets, release settings or default branches as part of routine governance.
4. Run only safe, applicable checks; report exact commands, results and unrun checks as NOT_RUN.
5. Do not publish private Vault contents, internal paths, credentials or personal data. Keep changes reversible and record the commit SHA.
