---
type: handoff
tags: [handoff, review, delivery, frontend, semantics, tooling]
---

# `if let` Review Outcome and Delivery Split

Continues [[handoffs/2026-08-28-if-let-pattern-condition]]. That handoff's Exact Next Action was
independent review before opening the issue #129 PR. This records what that review found, the
validation evidence it produced, and the delivery split [[ADR-0004]] requires before any PR opens.

## Defects the review found, and their fixes

**Macro hygiene was a name sweep, not a scope model.** Expansion pre-computed one rename map by
walking the macro body for every name it introduced, then substituted with that fixed map. A body
whose binders shadow one another, or whose pattern binders belong to one arm only, had no way to
say so. It is now lexical and statement-sequential: `substituteExpression` carries the expansion's
identifier and threads an *active* rename map through a block's statements in order, so each `let`
extends the map for the statements after it. An `if let`'s pattern binders enter that map only for
the success arm, through `renamePattern`, leaving the subject and the `else` in the caller's
environment. The subject, the success arm, and the fallback now each see exactly the names the
scope rule says they should.

**A control-flow head lost its brace at a parenthesis.** Brace classification tracked whether it
was inside a head so the following `{` opens a body rather than a record. A `(` cleared that flag
permanently, so a head containing parentheses of its own handed the next `{` to the record rule.
The head now resumes at the matching `)`: the state is saved when `(` opens and restored when it
closes, which also handles nesting. `if let Some(found) = value { found }` was the reported case,
classified as a record construction named `value` and written tight.

**That second defect is not particular to `if let`,** which is why the fix is stated against token
structure rather than a keyword sequence. Any head closing on a bare name offers the same false
record — `if f(a) == b { c }` reads `b { c }` as a construction of `b`. `testHeadAfterParens`
covers that spelling with no pattern condition in it, so the formatter change carries its own
regression and does not depend on `if let` existing.

## Validation evidence

| Gate | Result |
|---|---|
| Full suite, `-O0` | pass, 0 falsified |
| Full suite, `-O2` (`--enable-optimization=2`) | pass, 0 falsified |
| Warning-clean build | pass |

The `-O2` run is a separate gate rather than a formality: the unoptimised binary is roughly four
times slower, so a timing or a stack behaviour observed at `-O0` says little about the one that
ships.

## Delivery split

[[ADR-0004]] targets PRs under 400 changed lines. The slice is **807**, which `git diff` alone
understates: the vault pages are new files, and an untracked file is absent from a diff. Four units,
each independently motivated, each under the limit, each with the full suite passing on its own:

| Order | PR | Lines |
|---|---|---|
| 1 | vault: ADR-0010 and its handoff | 145 |
| 2 | `if let` surface and semantics | 357 |
| 3 | stdlib: `formDecode` branches once | 132 |
| 4 | macro hygiene becomes lexical and sequential | 173 |

Vault before implementation is this repository's order, not a preference. PR 4 cannot precede PR 2:
`substituteExpression` matches `IfLetExpression`, so the node must exist before hygiene renames
through it.

**A boundary the sizes did not show.** The first cut put `test/Pudu/Compiler/ProgramSpec.hs` with
the implementation and `test-fixtures/stdlib/UsesHttp.pudu` with the standard library. That file
carries the fixture's expected diagnostic count, so the expectation and the thing it measures were
separated and PR 2 failed alone with `Just "247" /= Just "266"`. The expectation belongs beside the
fixture. A split is only sound when each unit's suite passes on its own, which is why each was run
rather than reasoned about.

## Scope boundary, restated

`while let`, `let … else`, and pattern clauses inside boolean chains remain outside issue #129, as
the originating handoff states. Work on `let … else` and on carrier propagation belongs to its own
issue and its own branch; it must not ride along in any of the three PRs above.

## Exact Next Action

Cut PR 1 from the files it names, obtain independent review, merge to `dev`; then PR 2, then PR 3,
each with its own focused evidence plus the two full-suite gates above re-run on the split branch.
No PR opens carrying more than the unit it names.

## Referenced by

[[handoffs/_MOC]] · [[handoffs/2026-08-28-if-let-pattern-condition]] · [[ADR-0004]] ·
[[ADR-0010 Refutable Pattern Conditions]] · [[Format]] · [[Macro Expansion]]
