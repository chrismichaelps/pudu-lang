---
type: module
path: "@root/test-fixtures/stdlib/MemoRenderLocal.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, performance, refusal]
aliases: [Memo Render Local]
---

# Memo Render Local

## Purpose and interface

Refusal fixture for [[Std Mobile Memo]], imported under the alias `M`. Its `main` binds a module-level function `row` to a local `chosen` and passes the local to `M.Render`. The local holds a module-level function, but the checker cannot see through a binding what it was given, so the program must be refused with exactly one `E3103`, at the local's argument.

## Invariants

- The checker reports exactly one diagnostic, `E3103`, and no other code.
- The import alias `M` does not change the result: the rule is keyed by the type's identity.

## Negative Logic

- The fixture is not run. A program that passes the checker cannot be built from it.
- The fixture does not check the lambda form; that is [[Memo Render Lambda]].

## Dependencies and consumers

Depends on [[Std Mobile Memo]] and [[Std Mobile View]], and on the rule of [[Type Check Static]]. Asserted by the data spec [[Pudu Compiler Program Eval Data Spec]].

## Resolved Grill Log

- **Q:** Why refuse a local that holds a module-level function? **A:** The checker cannot see through a binding what it was given; refusing every local keeps the rule exact.

## Referenced by

[[Std Mobile Memo]] · [[Type Check Static]] · [[Pudu Compiler Program Eval Data Spec]]
