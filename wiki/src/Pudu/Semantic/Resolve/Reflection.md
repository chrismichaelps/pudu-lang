---
type: module
path: "@root/src/Pudu/Semantic/Resolve/Reflection.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, resolution, derive]
aliases: [Resolve Reflection]
---

# Resolve Reflection

## Purpose

Classify compile-time reflection imports by namespace and authored import identity.

## Interface

```haskell
reflectionImports :: [Located Import] -> Set (Namespace, Text)
fieldTypeParameter :: Located TypeSyntax -> Maybe (Text, Located Text)
```

## Governance

Read [[Derive Design]] and [[Pudu Semantic System]]. Resolution remains pure,
namespace-aware and lexical. No runtime reflection, type inference, IO or host
exceptions are introduced. Ordinary names and existing pattern behavior remain
unchanged.

## Algorithm

Enumerate aliases or bare module qualifiers in both namespaces; selected items use their selected names. Only Std.Meta imports enter the set. Resolved symbol origin and namespace decide whether a use denotes reflection, so shadowing in the other namespace cannot bypass refusal.

Extract the simple F position of a Field[T, F] annotation together with its
qualifier. This is a syntax candidate only: [[Resolve Context]] must confirm the
qualifier resolves to the reflection import before binding F. An unrelated Field
does not introduce a parameter.

## Negative Logic

Never infer capabilities from spelling alone or mutate shared compiler state.
Do not introduce a second name-resolution environment.

## Edge Cases

Empty lists and invalid recovery nodes are total. Shadowing follows the resolved
symbol in the namespace actually used. Unknown imports retain existing diagnostics.

## Grill Log

- **Q:** Where does this responsibility belong? **A:** Reject metadata uses at the shared resolved-reference boundary instead of scanning syntactic members. This covers selected imports, captured function values, aliases, types and bare module values without duplicate diagnostics.
  _Rationale:_ keep identity and scope decisions consistent across consumers.
  _Rejected:_ ad hoc syntactic checks and silent recovery.

## Linkage

Requires [[Syntax Tree]], [[Resolve Context]], [[Symbol Model]] and [[Name Resolution]].

## Referenced by

[[src/Pudu/Semantic/_MOC]] · [[Name Resolution]] · [[Resolve Context]]
