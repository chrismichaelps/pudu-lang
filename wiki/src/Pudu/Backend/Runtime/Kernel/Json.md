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

## Referenced by

[[Native Kernel Runtime]] · [[Native Builtin Kernels]]
