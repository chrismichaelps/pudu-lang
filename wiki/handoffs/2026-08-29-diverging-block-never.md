---
type: handoff
tags: [handoff, semantics, types, control-flow]
---

# Diverging Block `Never` Handoff

Issue #146 restores one existing language rule at the block boundary under
[[ADR-0012-diverging-blocks-preserve-never]]. `return`,
`break`, and `continue` have type `Never`, but [[Type Check Statement]] currently
turns a block ending directly in any of them into unit because the parser gives
that block no result expression. A `match` arm ending in `return` therefore
fails to join an ordinary value arm with `E3001: expected (), found Int`.

## FMCF role transition and ownership

The **Language Architect** owns the restored contract in [[grammar/pudu]] and
[[architecture/SEMANTICS]]: a resultless block ending in a direct control
transfer is `Never`; another resultless block is unit. This now transfers to the
**Semantic Engineer**, who owns only `src/Pudu/Type/Check/Statement.hs`, the
focused regression cases in `test/Pudu/Type/CheckSpec.hs`, this mirror, and the
changelog entry. Other agents are working in the repository; unrelated work is
preserved and no shared contract is changed outside this bounded slice.

The fresh warning-clean gate also recompiles every test helper and exposed three
omissions already present on `dev`: the `?` wrong-carrier fixture was computed
but never asserted, and the parser shape renderers did not cover the previously
merged `LetElseStatement` and `WhileLetExpression` nodes. The Semantic Engineer
also owns those three test-only repairs in `test/Pudu/Frontend/ParserBlockSpec.hs`
and `test/Pudu/Frontend/ParserExpressionSpec.hs`; they change no language or
production behavior and exist so the required clean-build gate can actually run.

Before delivery, a separate **Forensic Guardian** must inspect the implementation,
the focused tests, and wiki parity. The implementation author cannot be the sole
reviewer.

## Required evidence

- A returning `match` arm and an ordinary value arm join without `E3001`.
- Direct `return`, `break`, and `continue` endings supply `Never` in contextual
  block checks.
- A resultless block that can fall through remains unit and still reports a
  mismatch when joined with a value.
- `let … else` accepts a direct transfer through the ordinary inferred type,
  with its redundant structural exception removed.
- The baseline test helpers are exhaustive again and the existing wrong-carrier
  fixture asserts `E3011` instead of being discarded.
- Focused type tests, the full `-O0` and `-O2` suites, and the warning-clean build
  pass before the PR targets `dev`.

## Validation and review evidence

| Gate | Result |
|---|---|
| Full suite, `-O0` | pass, 0 falsified |
| Full suite, `-O2` | pass, 0 falsified |
| Fresh `-Werror` compilation at `-O0` and `-O2` | pass |
| Forensic Guardian review and remediation re-check | pass, no P0/P1 or unresolved P2/P3 |

Cabal linked every target cleanly; its final attempt to write the user-level
`~/.cabal/logs/build.log` is sandbox-denied in this workspace, so both produced
test binaries were executed directly for the recorded suite results.

## Exact Next Action

Commit the Forensic Guardian-reviewed slice, push it, open the issue #146 PR to
`dev`, and require its clean optimized CI before merge. Review found no P0/P1
implementation defect; it required the stable `E3001` span contract and the
semantic-version/ADR ledger treatment, both now included.

## Referenced by

[[handoffs/_MOC]] · [[Type Check Statement]] · [[grammar/pudu]] ·
[[architecture/SEMANTICS]] · [[ADR-0012-diverging-blocks-preserve-never]]
