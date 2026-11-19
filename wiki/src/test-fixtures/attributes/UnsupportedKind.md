---
type: module
path: "@root/test-fixtures/attributes/UnsupportedKind.pudu"
fidelity: Active
aliases: [Unsupported Kind Fixture]
tags: [module, test, attributes]
---
# Unsupported Kind Fixture

The declaration `attribute sizes(Array)` gives a parameter kind that is not a literal kind (`Str`, `Int`, `Float`, `Decimal`, `Bool`, `Char`). The declaration is refused with `E1069` at `Array`.

```pudu
module UnsupportedKind

/// An attribute argument is a literal; an array is not one.
attribute sizes(Array)

export fn main() -> Int { 0 }
```

Expected: one `E1069` diagnostic at `Array`.

## Referenced by

[[Declared Attributes Delivery]] · [[Program Attribute Spec]]
