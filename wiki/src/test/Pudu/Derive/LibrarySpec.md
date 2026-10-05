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
`UnmetStdField`: definition and field diagnostics, each callback refusal naming
its own kind and the answer type it found. `StdJsonValue`: a record holding
`Json`, `Option[Json]` and `Array[Json]` round-trips, an absent JSON field reads
`null`, and `Json.encode` stays the module's function. `InferredSelection`: `T.decode` through an imported trait with `T` inferred at the call, directly and from another generic function. `ShowChars`: a derived `Show` prints `'\''`, `'\"'` and `'\n'` the way their literals are written. A generated module of fifty records and fifty sums, each deriving six traits, checks with no diagnostics: coherence must not exhaust its budget on heads that cannot overlap. `SumMismatch`: a payload
read from another variant panics with `expected Shape.Circle` in both
evaluators. `Expand`: the snapshot in `Expand.expected`. `ExpandLocal`: the
printed expansion of same-module derives, written in place of the derive
definitions and `derives` entries, checks and answers what the derived program
answers in both evaluators.

## Grill Log

- **Q:** Compare against hand-maintained strings or regenerate? **A:** Fixed
  expected text, each delta inspected before it is changed.

## References

[[Derive Graph Spec]] · [[Derive Design]] · [[src/_MOC]]
