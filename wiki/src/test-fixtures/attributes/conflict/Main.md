---
type: module
path: "@root/test-fixtures/attributes/conflict/Main.pudu"
fidelity: Active
aliases: [Conflict Main Fixture]
tags: [module, test, attributes]
---
# Conflict Main Fixture

Imports [[src/test-fixtures/attributes/conflict/Tags]], which exports `tag(Str)`, then declares `tag(Int)` locally. Formation refuses the later declaration with `E3106`; the earlier parameters (`Str`) stand.

```pudu
module Main

import Tags

/// `Tags` already declares `@tag` taking text; a second meaning is refused here.
attribute tag(Int)

export fn main() -> Int { Tags.one() }
```

Expected: one `E3106` diagnostic at the `tag` declaration in this module.

## Referenced by

[[Type Formation]] · [[Declared Attributes Delivery]] · [[Program Attribute Spec]]
