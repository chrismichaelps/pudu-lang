---
type: handoff
tags: [handoff, semantics, control-flow]
---

# Labelled Loops Handoff

## Objective

Give the language a way to leave an outer loop from inside an inner one, and a way for a
loop to produce a value, without weakening either into a runtime surprise.

## FMCF Roles

- **Language Architect:** owned the surface decision (`@label` sigil over bare names), the
  typing rule for `loop`, and the choice to promote `break` outside a loop from a runtime
  failure to a compile error.
- **Semantics Engineer:** completed the issue #95 implementation across the lexer, parser,
  resolver, checker, and evaluator.
- **Forensic Guardian:** completed the audit of code/wiki fidelity, diagnostic-code
  allocation, and validation evidence.

## Resolved Contract

- A loop may be labelled `@name`; `break @name` and `continue @name` act on the loop that
  label names rather than the nearest enclosing one.
- `loop` has the type its `break` statements carry, and `Never` when none leaves it.
- `while` and `for` stay `()`, and a value carried out of one is `E3029`.
- Every jump resolves against a real loop before the program runs.

## Why the Sigil

The label needs a sigil because `break outer` is otherwise ambiguous: `outer` could be a
label or a binding whose value is being carried out. No lookahead settles it, and a reader
would have to know which loops were labelled to know what the statement did. `@` was free
in the symbol table, so the ambiguity is resolved in the grammar rather than in a rule the
reader has to remember.

## What Changed Behaviour

- `break` and `continue` outside every loop were previously runtime `E7006`. They are now
  `E2016` at resolution. `E7006` stays as a defensive evaluator path.
- A function body is no longer treated as inside a loop that encloses its definition. A
  closure may outlive the loop, so a `break` in one has nothing to leave and is `E2016`.
- The REPL classifies `@label for ...` as the statement it is. Classifying it as an
  expression evaluated it where its assignments could not reach the session's bindings —
  found by a test that read `0` where it should have read `2`.

## Diagnostics Allocated

`E1053` label naming no loop · `E2016` jump outside every loop · `E2017` label no enclosing
loop carries · `E3029` value carried out of `while`/`for` · `W2002` label shadowing a label.

## Exact Next Action

Commit and push the issue #95 branch and open its stacked PR against the documentation
site branch.

## Validation State

- Full property suite passes locally at `-O0` and `-O2` with the available GHC 9.10.3.
- `test-fixtures/stdlib/UsesLabels.pudu` exercises labelled break, labelled continue, and a
  value-carrying `loop`, and is wired into the program spec.
- The five new diagnostics were each confirmed against a live `pudu check`.
- The repository CI owns the locked GHC 9.14.1 gate before merge.

## Referenced by

[[handoffs/_MOC]] · [[Engineering Delivery]] · [[grammar/pudu]]
