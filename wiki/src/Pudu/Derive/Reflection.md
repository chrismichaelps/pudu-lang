---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Derive/Reflection.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, reflection]
aliases: [Derive Reflection Facts]
---

# Derive Reflection Facts

## Purpose and interface

`reflectionReferences :: Module -> Resolution -> Map Span ReflectionBinding`
projects resolved value references into MetadataModule or MetadataFunction Text.
The record residualizer receives this immutable canonical product instead of
matching source spellings. No individual trait/derive identity is recognized.

## Algorithm and invariants

Classify Std.Meta imports once, distinguishing module qualifiers from selected
members. Join references to the resolver's symbol IDs. Only actual import-origin
value symbols bound by those imports qualify; local shadowing cannot spoof them.
Inside the defining Std.Meta module, actual module-origin values identify its own
functions. Qualified access selects the member from a MetadataModule reference.

## Edge cases and negative logic

Aliases and selected functions identify the same module. Type references are not
callee facts. A local same-spelled binding is ordinary; no basename inference or
raw string search is permitted. No filesystem, expansion or typing work here.

## Grill Log

- **Q:** Match Meta.fields by text? **A:** No; use its resolved import identity.
  _Rationale:_ aliases and local shadowing already have correct symbol facts.
  _Rejected:_ spelling tests or a second lexical scope resolver.

## Referenced by

[[Derive Record Residualizer]] · [[Name Resolution]] · [[src/Pudu/_MOC]]
