---
type: module
path: "@root/src/Pudu/Compiler/Lower/Constant.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Constant]
---
# Compiler Lower Constant

## Purpose and interface

Own native projection of module-folded plain data under [[Native Folded
Constants]]. `lowerConstant` takes LowerState, the complete reference Span
and a written name path. It declines names that are not constants, or returns
the ordinary lowering result with either exact Core data or a located refusal.
State owns lexical/module lookup; Types owns settled facts and canonical
layouts. No backend module imports this compiler-owned boundary.

## Projection and failure

Read the immutable Frozen value supplied by the compiler, thaw it once for
projection, and use typeForSpan at the reference for its represented type.
Preserve raw floating bits/width, exact integer magnitude/kind and literal
text/Char/Bool/unit. Project tuple members at their corresponding types,
records at canonical layout field types in declaration order, and variants
by their expected sum's declared tag and payload types. Validate carrier,
field and payload shape before building Core; no partial indexing or invented
inhabitants. Every nested expression keeps the use's source provenance.

Unsupported frozen kinds, unavailable products, missing facts and mismatched
shapes return E6001 at the constant reference. Unused unsupported constants
need no native representation. Do not parse show output, evaluate syntax,
resolve aliases again, or change Core/runtime ABI.

## Resolved Grill Log

- A use's complete solved type determines identity, including imported aliases;
  a Frozen record/variant's display name alone is insufficient.
- Repeated constant reads may construct ordinary immutable owned values; they
  must follow the same cleanup and transfer paths as source literals.
- All fields/payloads are validated against the chosen canonical layout.
  A missing/extra member never truncates a zip into a different valid value.
- Missing folded products refuse; they do not silently execute the initializer.

## Dependencies and consumers

[[Compiler Lower State]] · [[Compiler Lower Types]] · [[Core IR]] ·
[[Compiler Lower Body]] · [[Native Folded Constants]]

## Referenced by

[[Native Folded Constants]] · [[Compiler Lower Body]]
