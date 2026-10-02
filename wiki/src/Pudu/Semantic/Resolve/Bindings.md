---
type: module
path: "@root/src/Pudu/Semantic/Resolve/Bindings.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, resolution, derive]
aliases: [Resolve Bindings]
---

# Resolve Bindings

## Purpose

Bind pattern names through the resolver context while preserving constructor qualification and mutability.

## Interface

```haskell
bindPattern :: Located Pattern -> Resolver ()
bindPatternWith :: Bool -> Located Pattern -> Resolver ()
```

## Governance

Read [[Derive Design]] and [[Pudu Semantic System]]. Resolution remains pure,
namespace-aware and lexical. No runtime reflection, type inference, IO or host
exceptions are introduced. Ordinary names and existing pattern behavior remain
unchanged.

## Algorithm

Walk tuple/sequence/constructor/record/alternative patterns in source order, resolve constructor heads through value/type qualification, and introduce value names in the current lexical frame. Discard and literal patterns bind nothing.

## Negative Logic

Never infer capabilities from spelling alone or mutate shared compiler state.
Do not introduce a second name-resolution environment.

## Edge Cases

Empty lists and invalid recovery nodes are total. Shadowing follows the resolved
symbol in the namespace actually used. Unknown imports retain existing diagnostics.

## Grill Log

- **Q:** Where does this responsibility belong? **A:** Keep this responsibility separate from the declaration/expression walk so that each module remains below the default size bound. Reuse the same resolver context and constructor rules rather than duplicating scope state.
  _Rationale:_ keep identity and scope decisions consistent across consumers.
  _Rejected:_ ad hoc syntactic checks and silent recovery.

## Linkage

Requires [[Syntax Tree]], [[Resolve Context]], [[Symbol Model]] and [[Name Resolution]].

## Referenced by

[[src/Pudu/Semantic/_MOC]] · [[Name Resolution]] · [[Resolve Context]]
