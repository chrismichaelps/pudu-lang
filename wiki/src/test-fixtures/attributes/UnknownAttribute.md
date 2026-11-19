---
type: module
path: "@root/test-fixtures/attributes/UnknownAttribute.pudu"
fidelity: Active
aliases: [Unknown Attribute Fixture]
tags: [module, test, attributes]
---
# Unknown Attribute Fixture

The field `@skp` is a misspelling of `skip`. Nothing in the program declares `skp`, so the use is refused with `E3104` at `skp`, naming the nearest declared attribute (`skip`, from the standard library) as help. The program declares no attributes of its own.

```pudu
module UnknownAttribute

import Std.Json as Json

/// `@skp` is a misspelling of `@skip`; it must not be silently ignored.
type Point = { x: Int, @skp y: Int } derives Json.Encode

export fn main() -> Int { 0 }
```

Expected: one `E3104` diagnostic at `skp`, help naming `skip`.

## Referenced by

[[Type Check Attribute]] · [[Declared Attributes Delivery]] · [[Program Attribute Spec]]
