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

`fieldCallee` recognizes a callee whose one parameter is a field-indexed callback: `Building owner result` for `build` and `Collecting owner element` for `collect`. `checkBuildCall` checks the literal once with its field type and `where` subjects rigid and bounds installed: a build callback answers F or `Result[F, E]` (giving T or `Result[T, E]`), a collect callback answers `Option[E]` (giving `Array[E]`); F may not escape into E.

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
- **Q:** Express build's `F or Result[F, E]` in the Meta signature? **A:** It cannot be; the rule is here, recognized by the callee's type rather than its spelling.
- **Q:** Accept a callback that is not a literal? **A:** No (E3001); unrolling needs its body.
- **Q:** Share one refusal wording and help between build and collect? **A:** No. _Rationale:_ a
  collect callback was told about build's answer shape. Each refusal names its own callback kind
  and the answer type it found, and the help writes that kind's literal. _Rejected:_ a generic
  "build callback" message for both.

## Linkage

Requires [[Type Env]], [[Type Unify]], [[Type Value]], [[Syntax Tree]], [[Std Meta]].
Consumed by [[Type Check Expression]].

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check Expression]] · [[Std Meta]]
