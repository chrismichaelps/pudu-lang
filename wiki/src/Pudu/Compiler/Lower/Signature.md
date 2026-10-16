---
type: module
path: "@root/src/Pudu/Compiler/Lower/Signature.hs"
fidelity: Active
domain: "[[Core IR]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, compiler]
aliases: [Compiler Lower Signature]
---

# Compiler Lower Signature

## Purpose and interface

Validate and memoize the callable native subset independently of expression lowering.

Exports: `ensureSignature, functionLevelRefusal`.

## Algorithm and invariants

Validate each reachable function once, including refused signatures. Admit explicit Int/Bool parameters without defaults and explicit Int/Bool/unit results. Reject unsupported function modifiers, constraints and bodies at their own spans; do not infer types again.

Function-level refusal stops signature admission. Otherwise parameter and
return refusals accumulate: missing parameter annotations point at parameter
names, unsupported annotations at the annotation, defaults at their own spans,
and a missing result annotation at the function name. The signature memo stores
both successful and refused answers, so multiple callers do not repeat them.
Type syntax maps unit and unqualified Int/Bool/Str names; Str is recognized so
its unsupported parameter/result refusal names the type accurately. Qualified,
generic, tuple and function types are outside the subset. Export visibility is
not inspected. Shared function admission rejects type parameters, async, unsafe,
comptime, constraints, missing bodies and expression bodies in that order.

## Negative logic

No host exceptions, semantic rechecking, global mutable state, or backend emission. Unsupported syntax remains a typed E6001 refusal.

## Dependencies and consumers

[[Compiler Lower State]] · [[Compiler Lower]] · [[Compiler Lower Body]] · [[Frontend Syntax]]. Only lowering modules consume this phase-owned module.

## Grill Log

- **Q:** Why extract this responsibility? **A:** State ownership and signature admission are stable boundaries independent of mutually recursive expression/block traversal. Each remains reviewable below 500 lines. _Rejected:_ an oversized body module or a circular expression split.
- **Q:** Can refactoring alter accepted semantics? **A:** No; only explicit corrections preventing invalid Core returns and Result erasure are permitted. Signature refusals and scope resolution retain their source provenance. _Rejected:_ backend inference or approximation.

## Referenced by

[[src/Pudu/Compiler/_MOC]] · [[Compiler Lower]] · [[Compiler Lower Body]]
