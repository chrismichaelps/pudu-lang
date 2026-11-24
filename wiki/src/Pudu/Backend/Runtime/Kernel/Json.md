---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel/Json.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native JSON Kernels]
---
# Native JSON Kernels

Export the family's runtime parts and their prerequisites.

Decode a JSON text into `Std.Json.Json` boxes, or nothing where the interpreter's reader answers nothing; encode a value compactly or indented. Variant indexes arrive as integers from lowering.

## Resolved Grill Log

Nesting is bounded at 512 as the interpreter bounds it. Trees are built as boxes directly and released on a refusal.

The reader constructs values as it validates the document. Each container
owns only its initialized entries, and recursively releases them on an
invalid child, delimiter, trailing byte, or allocation failure. Shared
fallible allocation helpers let the decoder release the partial tree before
reporting the original host memory failure. Strings without escapes copy a
validated span. Escaped strings decode into a buffer sized by the token scan.

## Referenced by

[[Native Kernel Runtime]] · [[Native Builtin Kernels]]
