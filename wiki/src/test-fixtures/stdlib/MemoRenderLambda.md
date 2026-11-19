---
type: module
path: "@root/test-fixtures/stdlib/MemoRenderLambda.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, performance, refusal]
aliases: [Memo Render Lambda]
---

# Memo Render Lambda

## Purpose and interface

Refusal fixture for [[Std Mobile Memo]]. Its `main` passes a lambda to `Memo.Render`, a constructor of a `@static_function` type, and the lambda reads `suffix`, a value that never reaches the memo's key. The program must be refused with exactly one `E3103`, at the lambda's argument, before anything runs.

## Invariants

- The checker reports exactly one diagnostic, `E3103`, and no other code.
- The refusal happens at the argument, not at the memo or at `main`.

## Negative Logic

- The fixture is not run. A program that passes the checker cannot be built from it.
- The fixture does not check the local-binding form; that is [[Memo Render Local]].

## Dependencies and consumers

Depends on [[Std Mobile Memo]] and [[Std Mobile View]], and on the rule of [[Type Check Static]]. Asserted by the data spec [[Pudu Compiler Program Eval Data Spec]].

## Resolved Grill Log

- **Q:** Why a lambda that reads a plain local rather than a mutable value? **A:** The stale-content case needs only a captured value; a plain local shows the capture with no other effect to confuse the diagnosis.

## Referenced by

[[Std Mobile Memo]] · [[Type Check Static]] · [[Pudu Compiler Program Eval Data Spec]]
