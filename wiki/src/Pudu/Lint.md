---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Lint.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, tooling, lint]
aliases: [Pudu Lint]
---

# Pudu Lint

## Purpose and interface

Analyze one successfully typed Pudu module and publish deterministic findings plus machine-checkable
edits. `lintModule` consumes the source, parsed module, and the compiler's `TypeInfo`; it returns
`LintResult`, whose `lintFindings` are ordered by source range and whose `lintStats` states exactly
how many expression nodes were visited. `applySafeFixes` applies a non-overlapping set of edits to
one immutable source snapshot.

Each `LintFinding` carries a stable ordinary Pudu `Diagnostic`, a rule name, and either no edit or a
`LintFix` whose applicability is `Safe`. The first native suggestion, `W7101`, replaces a typed
Boolean comparison with its unchanged Boolean operand only for `value == true`, `true == value`,
`value != false`, and `false != value`. It verifies the exact operator and literal text between AST
spans before publishing an edit, so expanded or synthetic syntax cannot be rewritten accidentally.

## Governance and algorithm

The analyzer walks an explicit work stack. Every declaration default, function body, nested block,
statement, control-flow arm, aggregate member, and expression child is scheduled once. Sequential
source therefore creates linear work and parser-bounded nesting cannot consume the host call stack.
Compiler warnings are adapted by [[Pudu CLI Lint]] rather than recomputed here.

Safe edits are sorted by outer source range, overlapping edits are not combined, and application
runs from the end of the text toward the start so earlier offsets remain stable. A fix never changes
files itself. The CLI owns atomic persistence and recompiles after a change.

## Negative logic and edge cases

- No untyped rewrite, name-spelling guess, general term-rewriting engine, or external refactoring
  executable.
- No edit is published merely because a help message sounds actionable.
- Comparisons with `false` through equality and `true` through inequality are not rewritten because
  inserting negation requires parent-precedence proof not yet carried by the fix contract.
- A parenthesized inner comparison is withheld because its expression span includes source wrapper
  text; an enclosing comparison may still carry one independently verified edit. Any overlapping
  edits supplied by future rules are reduced to a compatible batch.

## Grill Log

- **Q:** Copy HLint's rewrite language? **A:** No. _Rationale:_ Pudu already owns exact AST spans and
  inferred types; a second pattern language would lose semantic proof and add configuration parsing.
  _Accepted:_ public behavioral lessons—stable named rules, suppression, structured output, and
  conservative fixes. _Rejected:_ source-pattern substitution and an external refactor process.
- **Q:** Call a suggested change safe from syntax shape alone? **A:** No. _Rationale:_ Boolean
  equivalence also requires the compiler's inferred `Bool` type and exact source-span validation.
- **Q:** Claim faster-than-HLint performance from elapsed time? **A:** No. _Rationale:_ machines and
  workloads differ. _Accepted:_ expose visited-node counts, prove one visit per node, and benchmark
  separately before comparative claims.

## Referenced by

[[Pudu CLI Lint]] · [[Pudu Lint Spec]] · [[Pudu Module Map]] · [[Tooling]]
