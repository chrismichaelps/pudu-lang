---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Semantic/Resolve/Canonical.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, resolution]
aliases: [Resolve Canonical]
---

# Resolve Canonical

## Purpose and interface

Own `resolveHead`, `resolveMemberHead`, `resolveConstructorPath` and
`resolveTypePath` for the ordinary resolver walk. Qualified generated paths
inside a generated implementation are already canonically formed; their head
does not require an authored import. All other paths use existing value/type
resolution and namespace fallback.

## Algorithm and invariants

Read the scoped flag from [[Resolve Context]], require generated provenance and
more than one path segment before omitting a lexical-head lookup. Unqualified
type parameters, values, private helpers, locals and parameters always resolve.
The facade enables this scope only on an implementation produced by the graph
phase. This module introduces no binding, alias, import or visibility change.

## Edge cases and negative logic

Macro expressions in authored implementations do not enable the scope. A
single-segment generated unknown name remains an error. Constructor/member
heads retain the ordinary type fallback; plain value heads retain strict value
resolution. No type inference, filesystem lookup or last-segment identity.

## Grill Log

- **Q:** Add every graph module to the lexical scope? **A:** No; recognize
  already formed generated paths only. _Rejected:_ granting authored private
  access or capturing the consumer's imports instead of the definition's.
- **Q:** Skip local resolution in generated methods? **A:** No. _Rationale:_
  writable references and shadowing still need authoritative lexical symbols.

## Linkage and references

Requires [[Resolve Context]], [[Source]] and [[Syntax Name]]. Referenced by
[[Name Resolution]] · [[Derive Design]] · [[src/_MOC]].
