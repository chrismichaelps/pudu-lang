---
type: module
path: "@root/test-fixtures/attributes/UndeclaredRead.pudu"
fidelity: Active
aliases: [Undeclared Read Fixture]
tags: [module, test, attributes]
---
# Undeclared Read Fixture

The derive body for `Shown` calls `member.has("hidden")`, and nothing in the program declares `hidden`. The read is refused at its name, where it is written, with `E3104`; the derive is not allowed to answer false for every field. `Point` derives `Shown` so the definition is checked against a use.

```pudu
module UndeclaredRead

import Std.Meta as Meta

/// How many fields a record shows.
trait Shown {
  fn shown() -> Int
}

/// Reads `@hidden`, which nothing declares: the read is refused where it is
/// written, rather than quietly answering false for every field.
derive Shown for T: Record {
  fn shown() -> Int {
    Meta.collect[T](fn(member: Meta.Field[T, F]) -> Option[Int] { if member.has("hidden") { None } else { Some(1) } }).length()
  }
}

type Point = { x: Int, y: Int } derives Shown

export fn main() -> Int { 0 }
```

Expected: one `E3104` diagnostic at `"hidden"` in the derive definition.

## Referenced by

[[Type Check Attribute]] · [[Derive Design]] · [[Declared Attributes Delivery]] · [[Program Attribute Spec]]
