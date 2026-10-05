---
type: module
path: "@root/test/Pudu/Derive/LibrarySpec.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, test]
aliases: [Derive Library Spec]
---

# Derive Library Spec

## Purpose and interface

`deriveLibraryProperties` compiles real fixtures and runs them in the tree and
compiled evaluators, requiring identical rendered answers and no diagnostics.
It covers every shipped derive, field callbacks, static selection, the static
member regression, definition-site callback refusals, located field-bound
refusals and the exact `pudu expand` text.

## Coverage

`StdOrder`: Eq/Hash/Ord over records, sums, generic and recursive types.
`StdShow`: rendering of every payload shape and nested generics. `StdJson`:
renames, skips, text defaults, missing/duplicate/unknown keys, located decode
paths, every sum shape, generic and recursive round trips. `StdRow`: renamed,
nullable and strictly typed columns. `Builders`: `Result` builds with `?` and
early `return`, and variant builds. `StaticSelection`: generic functions,
generic derive targets and nested containers. `StaticMember`: a static member
selected by its owner, not its first argument. `BuildEscape` and
`UnmetStdField`: definition and field diagnostics. `Expand`: the snapshot in
`Expand.expected`.

## Grill Log

- **Q:** Compare against hand-maintained strings or regenerate? **A:** Fixed
  expected text, each delta inspected before it is changed.

## References

[[Derive Graph Spec]] · [[Derive Design]] · [[src/_MOC]]
