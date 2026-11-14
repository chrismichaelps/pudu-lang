---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Emit/Export/Crossing.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, backend, emit, native, mobile]
aliases: [Backend Export Crossing]
---

# Backend Export Crossing

## Purpose and interface

The C shape of every type an exported function passes or returns, the
declarations a host header carries for them, and the generated conversions
between those shapes and frame cells.

```haskell
crossingName :: Layouts -> CoreType -> Maybe Text
crossingDeclarations :: Layouts -> [CoreType] -> [Text]
crossingPrototypes :: Layouts -> [CoreType] -> [Text]
crossingHelpers :: Layouts -> [CoreType] -> [CoreType] -> [Text]
takeCell :: CoreType -> Text -> Text -> Text
giveValue :: CoreType -> Text -> Text
crossingNeeds :: Layouts -> [CoreType] -> [CoreType] -> [Text]
```

## Algorithm and invariants

- Fixed-width integers up to 64 bits, `Float32`, `Float64` and `Bool` cross by
  value with the C types foreign calls use.
- Text crosses as `pudu_string`, a struct of `const char *bytes` and
  `size_t length` holding UTF-8. A text parameter is checked as UTF-8 and copied
  into an owned Pudu text; bytes the host still owns are never kept. A text
  result is an owned, NUL-terminated copy the host releases with
  `pudu_string_release`; the terminator is not counted in `length`.
- A record crosses as a struct named `pudu_<Name>` (generic records add their
  type arguments to the name) whose members carry the Pudu field names, in
  declaration order, with each member's own crossing: nested records nest, text
  members are `pudu_string`. A field named like a C keyword gets a trailing
  underscore.
- For each record a parameter reaches, `pudu_export_take_<Name>` builds the box
  from the struct, converting members first and releasing its own references
  after the constructor retains them. For each record a result reaches,
  `pudu_export_give_<Name>` builds the struct from a box without consuming the
  box. Only the directions a program uses are emitted.
- `crossingDeclarations` is the same text in the header and in the program, so
  both translation units see one struct per type.
- `crossingPrototypes` gives the header the declaration of `pudu_string_release` when any result reaches text; the program defines it as an external function so a host can call it.
- Records cross only with at least one field and without containing themselves; an empty or self-containing record has no crossing.
- Text that is not UTF-8, or a null `bytes` with a nonzero length, stops the call
  through `pudu_export_misuse` naming the export: it is a host programming error.

## Negative Logic (Prohibited Paths)

- No lookup or reflection at run time.
- No retained pointer into host memory.
- No text result the host cannot release.
- No crossing for sums other than a `Result` result, closures, collections,
  bytes or handles; these are refused at the export.

## Dependencies and consumers

Uses [[Backend Emit Foreign ABI]] for scalar conversions and the aggregate
helpers of [[Native Aggregate Emission]]. Consumed by [[Backend Emit Export]].

## Grill Log

- **Q:** Why bytes and length instead of a NUL-terminated `const char *`?
  **A:** Platform string constructors take bytes and a length, so neither side
  scans for a terminator, and Pudu text may contain U+0000. _Rejected:_
  NUL-terminated text at the export boundary.
- **Q:** Why owned copies for text results? **A:** The Pudu text is released when
  the call returns, and the host's lifetime is unknown to Pudu. One allocation per
  text result with an explicit release is the smallest contract that is always
  safe. _Rejected:_ borrowed results valid until the next call.
- **Q:** Why public structs with field names instead of the foreign record
  structs? **A:** The host writes `point.x`, not `point.f0`, and the header must
  be readable as an API. _Rejected:_ positional member names.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Backend Emit Export]] · [[Native Export Crossings Delivery]]
