---
type: domain
tags: [domain]
aliases: [Type]
---

# Pudu Type

- **Definition:** A compile-time classification determining representation constraints, valid operations, ownership behavior, and failure/effect obligations.
- **Core forms:** primitive, function, tuple, record, algebraic variant, nominal generic instance, reference, mutable reference, array, type variable, and unit.
- **Absence:** `Option[T]`; `null` exists only as an unsafe foreign-boundary literal and never inhabits an ordinary Pudu type.
- **Inference:** Local expressions and omitted private parameter annotations may infer; exported signatures require explicit parameter and return types.
- **Not:** A runtime class object or an implicit nullable annotation.

## Referenced by

[[Semantics]] · [[Ownership]] · [[Core IR]] · [[grammar/pudu]]
