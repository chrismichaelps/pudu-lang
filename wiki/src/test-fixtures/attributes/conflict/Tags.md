---
type: module
path: "@root/test-fixtures/attributes/conflict/Tags.pudu"
fidelity: Active
aliases: [Conflict Tags Fixture]
tags: [module, test, attributes]
---
# Conflict Tags Fixture

Exports `tag(Str)` for other modules to use. On its own it has no diagnostic; it supplies the earlier declaration that [[src/test-fixtures/attributes/conflict/Main]] conflicts with.

```pudu
module Tags

/// A tag written as text.
export attribute tag(Str)

export fn one() -> Int { 1 }
```

Expected: no diagnostic.

## Referenced by

[[Type Formation]] · [[Declared Attributes Delivery]] · [[Program Attribute Spec]]
