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
Constants]]. `lowerConstant` takes the expression lowerer, LowerState, the
complete reference Span and a written name path. The callback lets a constant
without a product compile its initializer in its own module. It declines names
that are not constants, or returns the ordinary lowering result with either
exact Core data or a located refusal. State owns lexical/module lookup; Types
owns settled facts and canonical layouts. No backend module imports this
compiler-owned boundary.

## Projection and failure

Read the immutable Frozen value supplied by the compiler, thaw it once for
projection, and use typeForSpan at the reference for its represented type.
Preserve raw floating bits/width, exact integer magnitude/kind and literal
text/Char/Bool/unit. Project tuple members at their corresponding types,
records at canonical layout field types in declaration order, and variants
by their expected sum's declared tag and payload types. Validate carrier,
field and payload shape before building Core; no partial indexing or invented
inhabitants. Every nested expression keeps the use's source provenance.

Unsupported frozen kinds, missing facts and mismatched shapes return E6001 at
the constant reference. A declared constant whose folding left no portable
product compiles its written initializer there instead, in the declaring
module. Unused unsupported constants need no native representation. Do not
parse show output, evaluate syntax at runtime, resolve aliases again, or
change Core/runtime ABI.

## Resolved Grill Log

- A use's complete solved type determines identity, including imported aliases;
  a Frozen record/variant's display name alone is insufficient.
- Repeated constant reads may construct ordinary immutable owned values; they
  must follow the same cleanup and transfer paths as source literals.
- All fields/payloads are validated against the chosen canonical layout.
  A missing/extra member never truncates a zip into a different valid value.
- Missing folded products compile their written initializer in the declaring
  module; they do not run it at runtime or read the reader's locals.

## Dependencies and consumers

[[Compiler Lower State]] · [[Compiler Lower Types]] · [[Core IR]] ·
[[Compiler Lower Body]] · [[Native Folded Constants]]

## Generic records (#552)

Pattern update only: `CoreRecordType` has an argument list; behavior is unchanged.

## Referenced by

[[Native Folded Constants]] · [[Compiler Lower Body]]

## Frozen Bytes

Resolved Grill Log: project an exact frozen ByteString as a Core array of
UInt8 literals followed by BytesOfArray. Arbitrary bytes, including invalid
UTF-8 and NUL, must survive without decoding. This recursively covers Bytes
inside represented tuples, records and variants; ordinary aggregate cleanup
owns each constructed value. No initializer evaluation occurs at runtime.

## Canonical folded values (#798)

Folding now publishes a record under its canonical owner and a sum value as
`SumValue` or, for a record variant, `NamedSumValue`, each under its
canonical owner. A record matches by its key or display name; a sum value by
its variant label, the solved type having already chosen the owner; a named
payload must list the variant's fields in declaration order.

## Decimal (#802)

A folded Decimal projects to its literal.

## Frozen collections and ranges (#808)

Project ArrayValue members recursively against the solved element type.
MapValue entries in stored ascending order become typed key/value tuples,
then a CoreArray and KeyedFromArray; SetValue members follow the same path.
Preserve the held representative's exact bits and nominal identity. RangeValue
becomes CoreRangeValue with independent optional platform-Int endpoints and
the original inclusivity flag. Every nested expression keeps the use span.

Resolved Grill Log: frozen keys contain no callable/resource data, so their
existing validity requires no new runtime key-order test. Recursively reject
any malformed element or endpoint rather than truncating, coercing, sorting
by rendered names, or evaluating initializers. Ordinary carriers own cleanup.

## Indexed stores (#840)

A folded store projects as the from-array builder over its (Int, value) pairs in key order. Resolved Grill Log: reuse the map projection; keys are already narrowed.

## Initializer fallback (#846)

When folding leaves no product, `lookupInitializer` finds the declaring module
and its written expression. Lowering enters that module, clears the reader's
lexical scopes, loops and loans, compiles the expression there, and restores
the reader's module, facts, scopes, loops and loans. The Core data keeps the
use span. A supplied product is preferred; a malformed supplied product still
refuses rather than falling back. A callable table such as
`Array[fn(Int) -> Int]` therefore becomes ordinary closures.

Resolved Grill Log: compiling an initializer at its use is not evaluating it
at runtime. Folding already denied effects, so every read answers the same
value the one evaluation would, and the reader's locals never become visible
to the initializer.
