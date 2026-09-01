---
type: handoff
status: REVIEW
issue: 189
tags: [handoff, repl, tooling]
---

# Static REPL Type Inspection

## Defect

`:type` uses the ordinary submission path. Asking for the type of
`print("TYPE_SIDE_EFFECT")` therefore prints `TYPE_SIDE_EFFECT`, and asking for
the type of a runtime failure reports the runtime failure instead of the static
type. Ignoring the resulting value cannot undo evaluation.

## Ownership

The Tooling Engineer owns the bounded type probe in `Pudu.Repl.Session`, the
`:type` presentation in `Pudu.Repl.Answer`, their mirrored pages, regression
coverage, this handoff, and the changelog entry. This slice does not change
Pudu syntax, evaluator semantics, the language server, Std.Path, or issue #188.
Other work may exist in the repository; preserve it and do not revert unrelated
changes.

## Contract

- One probe assembles and compiles the same interactive buffer as submission.
- The probe stops before evaluation and returns source mapping, compiler
  diagnostics, and the inferred expression type.
- `:type` renders diagnostics or the static type and says `no type` for an
  entry without an expression type.
- Warning diagnostics precede the static type; error diagnostics are terminal.
- Completion consumes a narrow `Maybe Type` view of the same probe.
- A regression must prove static success, compiler failure, statement behavior,
  and non-evaluation through a runtime-error tripwire.

## Review

An independent Forensic Guardian must verify that no inspection path enters the
evaluator, the source-relative diagnostics remain intact, the focused regression
passes, warning-bearing valid input still prints its type, the diff stays
review-sized, and the vault mirrors match the code.

The first Guardian pass found P1: `showType` treated a non-empty diagnostic list
as terminal, so a valid expression carrying W3003 printed the warning but hid
its type. The fix distinguishes errors from warnings and adds a captured-output
regression in the focused Answer test module before the second review pass.

## Grill Log

- **Q:** Is a dry-run evaluator sufficient? **A:** No. _Rationale:_ a second
  evaluation mode is another runtime semantics and still risks effects from the
  accumulated buffer. Static inspection already ends at the compiler.
- **Q:** Should `:type` and completion probe separately? **A:** No. _Rationale:_
  one compiler path prevents their source offsets and inferred types from
  drifting.

## Exact Next Action

Push the verified P1/P2 corrections to PR #192, then obtain second
implementation and Forensic Guardian reviews before merge.

## Referenced by

[[handoffs/_MOC]] · [[Pudu REPL]] · [[Repl Answer]] · [[Repl Session]]
