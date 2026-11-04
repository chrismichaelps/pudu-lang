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

[[architecture/OVERVIEW]] · [[Tooling]] · [[Pudu Module]]

## Nominal data identity

Runtime nominal data retains its canonical declaration owner. Named sum values additionally carry a short variant label and named fields in a distinct shape from ordinary records and positional sums; display labels never establish identity. See [[Eval Value]] and [[Named Sum Value Delivery]].

Resolved Grill Log: a nested-module record key can equal a textual sum owner plus variant; separate shapes prevent that collision.
