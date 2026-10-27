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

- **Q:** Why memoize by canonical name? **A:** Two modules may each declare a function of one name; the scheme itself is still read by bare name from the function's own module's facts (#539).

- **Q:** Why extract this responsibility? **A:** State ownership and signature admission are stable boundaries independent of mutually recursive expression/block traversal. Each remains reviewable below 500 lines. _Rejected:_ an oversized body module or a circular expression split.
- **Q:** Can refactoring alter accepted semantics? **A:** No; only explicit corrections preventing invalid Core returns and Result erasure are permitted. Signature refusals and scope resolution retain their source provenance. _Rejected:_ backend inference or approximation.

## Instance schemes (#551)

Resolved Grill Log: an instance supplies its own scheme. Its rigid parameters
must all be bound in the current facts; their bounds were proved by checking
for those types, so bounds are accepted only then. A monomorphic scheme still
needs no bounds.

## Bound type parameters (#552)

Resolved Grill Log: a function's type parameters and constraints refuse only
when its type parameters are not all bound, so a specialized copy is admitted
and the entry and plain functions keep their refusals.

## Referenced by

[[src/Pudu/Compiler/_MOC]] · [[Compiler Lower]] · [[Compiler Lower Body]]


## Solved native type inputs (#491)

Replace syntax-based type projection with final schemes from Compiler Lower Types. Reject scheme parameters/bounds, asynchronous/optional/arity-mismatched function shapes, unsupported formed parameter/result representations. Admit inferred Int/Bool parameters and inferred Int/Bool/unit results plus aliases. Source modifiers, constraints, defaults and block-body policy remain. Unsupported parameters use annotation span when present, otherwise parameter name; results use annotation or function name. Missing or nonmonomorphic scheme refuses function name. Memoization and reachable-only traversal remain.

Resolved Grill Log: consume canonical settled checker facts; preserve structural Never, print carrier refusals and existing runtime representations. Rejected: re-inference, display-name ABI selection, offset-only identity or silent fallback.


## Unit literals and parameters (#492)

Admit settled CoreUnitType parameters alongside Int/Bool through canonical UnitTypeValue projection. Keep the parameter slot and ordinary source arity; aliases use the same formed identity. Defaults, generic and unsupported signatures remain refused.

Resolved Grill Log: preserve the single unit inhabitant and every effect without allocating a new representation. Reject void-valued C initializers, Result erasure and omitted argument evaluation. Nonempty tuples remain pending; #493 implements unit display/equality.

## Text signatures (#515)

Parameters and results admit `nativeValueType`, so Str crosses calls.

## Records (#521)

Parameter and result types form through `formedCoreTypeIn`, so record types
are admitted.

## Expression bodies (#567)

Resolved Grill Log: Accept an existing expression body as well as a block body; leave default values, modifiers and all solved-type restrictions unchanged. See [[Native Expression Bodies]].

## Defaults (#638)

A signature with defaults admits all parameters plus a trailing Int count
named "". A required parameter after a default refuses with E6001.
Resolved Grill Log: the scheme's required count must equal the parameters
without a default; defaults only fill from the end.
