---
type: module
path: "packages/pudu/v0.1/lib/Std/Meta.pudu"
fidelity: Active
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, derive]
aliases: [Std Meta]
---

# Std Meta

## Purpose and interface

Declare compile-time shape descriptors and their ordinary accessor contracts.
Field[T, F] and Variant[T] expose a Str name property. A field's get accepts &T
and returns F; set accepts &mut T and F. Attribute reads preserve the fallback's
type. A variant matches &T and exposes its payload fields and constructor.
nameOf, fields, variants and build retain the authored Meta API.

Fields[T] and Variants[T] are opaque compile-time sequences. Fields does not
carry a homogeneous element parameter: each iteration introduces its own rigid
F. Only compile-time iteration consumes these sequences; ordinary Array operations
cannot access them. This facade is declaration groundwork: panic bodies have no
runtime implementation. The complete integration must eliminate every descriptor
and accessor before evaluation, implement rank-polymorphic build callbacks and
Result construction, and refuse any surviving reflection.

## Algorithm and boundaries

Ordinary trait schemes provide owner-specific accessors. The checker recognizes
only canonical Std.Meta sequence identities, validates loop descriptor ownership,
and checks each body against an abstract field type. User trait names never enter
the compiler. Resolver restrictions cover all imported Meta names, including aliases
and selected imports, outside derive definitions.

## Grill Log

- **Q:** Return Array[Field[T, F]] from fields? **A:** No. Fields[T] preserves
  heterogeneity without allowing inference to choose one concrete F for a whole
  record. _Rejected:_ a hidden homogeneous inference variable.
- **Q:** Accept a new V owner in get and matches? **A:** No. Their owner is T;
  set additionally preserves exclusive borrowing and the held field type.
- **Q:** Are panic bodies evidence of runtime derivation? **A:** No. They supply
  signatures only; residualization and Result builders remain integration gates.

## Linkage

Requires [[Derive Design]], [[Name Resolution]], [[Type Check Reflection]].
Consumed by [[Type Check Expression]] and [[Program Reflection Spec]].

## Referenced by

[[src/Std/_MOC]] · [[Derive Design]]
