---
type: domain
tags: [domain]
aliases: [Core Intermediate Representation]
---

# Core IR

- **Definition:** Typed, name-resolved, ownership-checked representation with explicit control flow, calls, construction, destruction, borrows, and failure propagation.
- **Invariant:** It contains no unresolved names, surface sugar, implicit moves, or ambiguous numeric operations.
- **Not:** Parser AST or target-specific C syntax.

## Referenced by

[[architecture/OVERVIEW]] · [[Interpreter]] · [[Native Backend]] · [[Ownership]]
