---
type: module
path: "@root/test-fixtures/attributes/DeclaredAttribute.pudu"
fidelity: Active
aliases: [Declared Attribute Fixture]
tags: [module, test, attributes]
---
# Declared Attribute Fixture

Declares `tag(Str)`, `weight(Float)` and `flag`, then uses them with arguments of their kinds: `@tag("x")`, `@weight(2)` (an integer literal is accepted for `Float`) and `@flag`. The field `@json("why")` names the standard library's `json`, imported through `Std.Json`. The program must compile with no diagnostic.

```pudu
module DeclaredAttribute

import Std.Json as Json

/// Attributes this module gives meaning to; each use below matches its kinds.
attribute tag(Str)
attribute weight(Float)
attribute flag

type Point = { @tag("x") @weight(2) x: Int, @flag @json("why") y: Int } derives Json.Encode

export fn main() -> Int { 0 }
```

Expected: no diagnostic.

## Referenced by

[[Type Check Attribute]] · [[Declared Attributes Delivery]] · [[Program Attribute Spec]]
