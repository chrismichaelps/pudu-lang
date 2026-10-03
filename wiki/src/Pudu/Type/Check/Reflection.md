---
type: module
path: "packages/pudu/v0.1/src/Pudu/Type/Check/Reflection.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, types]
aliases: [Type Check Reflection]
---

# Type Check Reflection

## Purpose and interface

`reflectedParameters` discovers an unbound field parameter only in a canonical
Std.Meta.Field[T, F] annotation. Existing rigid or declared type names retain their
identity. `checkSequenceElement` checks Fields[T] against Field[T, F] with an
fresh abstract F, Variants[T] against Variant[T], or an ordinary Array against its element.
An enclosing type parameter cannot stand for every independently chosen field type;
nested field loops use a distinct fresh name. Built-in and declared types never bind
implicitly, including when a where clause repeats their spelling.

## Algorithm

Canonical nominal identities determine metadata, including aliased and selected
imports. Sequence ownership unifies at the loop source. An invalid descriptor or
concrete heterogeneous field annotation reports one E3001, returns error poison,
and prevents cascading body errors. No source expression is skipped.

## Negative logic

Do not add runtime metadata, infer field capabilities, accept a same-spelled user
type as Std.Meta, or treat Fields as a homogeneous Array. No IO or recursive checks.

## Grill Log

- **Q:** Bind every unknown annotation name? **A:** No. Only the simple F position
  of canonical Field introduces a fresh type parameter. Typos elsewhere remain
  unresolved names. Existing type parameters are reused lexically.
- **Q:** Share Array inference for reflected fields? **A:** No. Require an abstract
  field parameter and the same owner; each real field substitutes independently.

## Linkage

Requires [[Type Env]], [[Type Unify]], [[Type Value]], [[Syntax Tree]], [[Std Meta]].
Consumed by [[Type Check Expression]].

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check Expression]] · [[Std Meta]]
