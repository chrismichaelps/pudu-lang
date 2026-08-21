---
type: domain
tags: [domain]
aliases: [Program]
---

# Pudu Program

- **Definition:** One or more [[Pudu Module]] values whose imports resolve, declarations type-check, ownership rules hold, and entry-point contract is satisfied.
- **Canonical name:** Pudu Program.
- **Not:** A single source file or an unchecked syntax tree.
- **Example:** `App.pudu` importing `Collections` and exporting `fn main() -> Result[(), Error]`.

## Referenced by

[[architecture/OVERVIEW]] · [[Compiler Pipeline]] · [[Pudu Module]]
