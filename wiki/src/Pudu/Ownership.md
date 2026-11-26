---
type: module
path: "@root/src/Pudu/Ownership.hs"
fidelity: Active
domain: "[[Ownership]]"
subsystem: "[[Type Checker]]"
grammar: "[[grammar/haskell]]"
tags: [module, ownership]
aliases: [Ownership Marks]
---

# Ownership Marks

## Purpose

Carry the two facts ownership checking settles—a use that moves a value
needing drop, and a binder that owns one—through the settled module to every
engine. Both engines read the same settled syntax, so a cached module keeps
the facts a freshly checked one has.

## Interface

`moveOperator` is `"::move"`; `ownedBinderKind` is `"::owned"`.

- The move set is applied by `resolveLiterals`, which wraps a marked bare
  local in `UnaryExpression "::move"`. A field shorthand `{name}` is rewritten
  to the same marked local.
- The owned spans are folded into `moduleIntegerKinds` under
  `ownedBinderKind`, beside the resolved literal kinds.

## Contract

No source spelling produces `"::move"`. The checker is the only producer, and
it marks only a use of a local that moves a value needing drop. The
interpreter reads the operator as a move and clears the binding; native
lowering reads it as `CoreTakeLocal`. The owned marker never shares a span
with an integer literal: a binder is not an expression position.

The marker travels in the settled module rather than in a separate cache
field. A second field would need its own cache key and could disagree with the
syntax a cache hit replays; the marker cannot.

## Negative Logic

`"::move"` does not wrap a member, an index, a call or a module value. A
moving use that is not a bare local is a construct the checker refuses with
E4002, E4004 or E4006 before lowering sees it.

## Edge Cases

A module that declares its own `Drop` trait does not get the prelude's drop
behavior; `Type.Drop` decides that identity before any span is marked.

## Resolved Grill Log

- **Q:** Why not a separate move set on the compiled product? **A:** The
  settled module already reaches the interpreter and native lowering, and a
  cache hit replays it. Folding the marker into that module keeps one source
  of truth. _Rationale:_ a parallel field would need independent cache
  plumbing and could drift from the syntax it describes.
- **Q:** Why reuse the integer-kind map for owned binders? **A:** The map is
  already the per-span fact channel that survives caching, and a binder span
  is never an integer literal. _Rationale:_ one channel, one lifetime, no new
  product shape.
- **Q:** Why is the operator not exposed as source syntax? **A:** Programs
  must not be able to spell a move the checker did not prove. _Rationale:_
  ownership validity would otherwise become advisory.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Ownership]] · [[Compiler Literals]] · [[Eval Drop]] · [[Compiler Lower Drop]]
