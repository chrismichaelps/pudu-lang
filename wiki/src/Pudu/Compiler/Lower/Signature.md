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

## Fixed signed admission (#497)

Use nativeScalarType for parameters/results, adding canonical fixed signed
integers through the existing formed projection. Resolved Grill Log: retain
monomorphic/required-arity checks, memoization, source refusal spans and no
normalization or inference at the call ABI.

## Purpose and interface

Validate and memoize the callable native subset independently of expression lowering.

Exports: `ensureSignature, functionLevelRefusal`.

## Algorithm and invariants

Validate each reachable function once, including refused signatures. Source
modifiers, constraints, default values and body shape retain their existing
refusals. Defaults point at their expression span. Consume the final scheme
from [[Compiler Lower Types]]: synchronous, monomorphic, all parameters required,
and arity equal to source parameters. Represented parameters/results are admitted
integers, Bool and unit. Inferred and aliased types share this projection.

Unsupported formed types point at the annotation when present, otherwise the
parameter/function name. Missing or polymorphic schemes refuse at the function
name. Unresolved result variables refuse rather than becoming unit: for example,
the checker currently leaves an unannotated bare-return helper result unresolved.
Successful and refused signatures are memoized across callers. Annotation spelling
never selects the C representation; no second inference pass runs here.

## Negative logic

No host exceptions, semantic rechecking, global mutable state, or backend emission. Unsupported syntax remains a typed E6001 refusal.

## Dependencies and consumers

[[Compiler Lower State]] · [[Compiler Lower]] · [[Compiler Lower Body]] · [[Frontend Syntax]]. Only lowering modules consume this phase-owned module.

## Grill Log

- **Q:** Why extract this responsibility? **A:** State ownership and signature admission are stable boundaries independent of mutually recursive expression/block traversal. Each remains reviewable below 500 lines. _Rejected:_ an oversized body module or a circular expression split.
- **Q:** Can refactoring alter accepted semantics? **A:** No; only explicit corrections preventing invalid Core returns and Result erasure are permitted. Signature refusals and scope resolution retain their source provenance. _Rejected:_ backend inference or approximation.

## Referenced by

[[src/Pudu/Compiler/_MOC]] · [[Compiler Lower]] · [[Compiler Lower Body]]


## Solved native type inputs (#491)

Replace syntax-based type projection with final schemes from Compiler Lower Types. Reject scheme parameters/bounds, asynchronous/optional/arity-mismatched function shapes, unsupported formed parameter/result representations. Admit inferred Int/Bool parameters and inferred Int/Bool/unit results plus aliases. Source modifiers, constraints, defaults and block-body policy remain. Unsupported parameters use annotation span when present, otherwise parameter name; results use annotation or function name. Missing or nonmonomorphic scheme refuses function name. Memoization and reachable-only traversal remain.

Resolved Grill Log: consume canonical settled checker facts; preserve structural Never, print carrier refusals and existing runtime representations. Rejected: re-inference, display-name ABI selection, offset-only identity or silent fallback.


## Unit literals and parameters (#492)

Admit settled CoreUnitType parameters alongside Int/Bool through canonical UnitTypeValue projection. Keep the parameter slot and ordinary source arity; aliases use the same formed identity. Defaults, generic and unsupported signatures remain refused.

Resolved Grill Log: preserve the single unit inhabitant and every effect without allocating a new representation. Reject void-valued C initializers, Result erasure and omitted argument evaluation. Nonempty tuples remain pending; #493 implements unit display/equality.
