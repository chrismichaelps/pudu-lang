# Pudu Agent Operating Contract

All agent work in this repository is governed by the vault at `wiki/`. The local private project inputs `fmcf.md`, `lang_proposal.md`, and `goal.md` must remain ignored and must never be staged, committed, quoted into PRs, or exposed in generated artifacts.

## Required re-anchor

Before acting, read:

1. `wiki/00-INDEX.md` and relevant MOCs.
2. The active `wiki/handoffs/` page, if one exists.
3. `wiki/grammar/haskell.md` before Haskell changes.
4. `wiki/grammar/pudu.md` and `wiki/architecture/SEMANTICS.md` before Pudu syntax, fixtures, or semantics.
5. Every mirrored module page corresponding to files in the assigned scope.

If the private local governance inputs are present, they may be read for local alignment. The distilled vault—not those private files—is the shareable repository source of truth.

No implementation file may be created or changed before its complete mirrored page exists under `wiki/src/` and contains a resolved Grill Log.

## Roles and ownership

- Declare FMCF role transitions in the handoff page.
- Every implementation assignment names owned files or a bounded responsibility.
- Agents are not alone in the codebase. Preserve other work, do not revert unrelated changes, and coordinate shared contracts through the vault.
- Concurrent agents must have non-overlapping file ownership unless an Architect explicitly sequences a shared-contract handoff.
- An implementation author cannot be the sole reviewer of that implementation.

## Delivery

- Follow `wiki/architecture/DELIVERY.md` and `CONTRIBUTING.md`.
- Work begins from a ready issue and a fresh `feature/<issue>-<slug>` branch from `dev`.
- Commits use `type(scope): imperative summary refs #<issue>`.
- PRs target `dev`, remain reviewable, and include focused plus full validation evidence.
- Semantic/public changes require Language Architect review. Every PR requires Forensic Guardian wiki-parity review.

## Quality

- Every feature has success, failure, regression, and diagnostic/output tests where applicable.
- Never hide failing checks, update snapshots without inspecting the semantic delta, or claim formal/safety guarantees without their required evidence.
- Keep source files below 500 lines by default and split responsibilities before they become shallow.
- Comments explain invariants and phase boundaries, not obvious operations.

## Completion

Code and wiki must match in the same turn. Update backlinks, MOCs, and `wiki/CHANGELOG.md`. If work remains, leave a handoff page with one exact next action.
