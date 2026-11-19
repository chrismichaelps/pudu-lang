---
type: module
path: "@root/test-fixtures/attributes/WrongAttributeArgument.pudu"
fidelity: Active
aliases: [Wrong Attribute Argument Fixture]
tags: [module, test, attributes]
---
# Wrong Attribute Argument Fixture

The field `@json(1)` passes an integer where the standard library's `json` takes a `Str`. The use is refused with `E3105` at the argument.

```pudu
module WrongAttributeArgument

import Std.Json as Json

/// `@json` takes the key as text, not a number.
type Point = { x: Int, @json(1) y: Int } derives Json.Encode

export fn main() -> Int { 0 }
```

Expected: one `E3105` diagnostic at `1`, expecting a `Str` argument.

## Referenced by

[[Type Check Attribute]] · [[Declared Attributes Delivery]] · [[Program Attribute Spec]]
