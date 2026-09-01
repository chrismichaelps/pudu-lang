---
type: module
path: "@root/lib/Std/Toml.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, toml, configuration]
aliases: [Std Toml]
---
# Std Toml
## Purpose
Parse and render TOML 1.0 configuration without rounding numeric/date-time spellings or losing key order.
## Interface
Exports the recursive value model — text, whole numbers, fractional numbers as their source text,
truths, moments as their source text, lists, and tables — with typed projections, field and dotted
path lookup, key listing, table construction, key rendering, and document encoding. Reading lives
in [[Std Toml Read]] so that a change to number syntax is not a change to document structure.
## Governance and algorithm
Tables retain declaration order while lookup follows dotted paths. `encode` writes plain values
before any section, because a key written after a section header belongs to that section: emitting
entries in stored order would silently move a top-level setting inside the section above it, which
is the one writer mistake that still produces a valid file meaning something else. Duplicate keys, redefining a
value as a table, extending an inline table, malformed escapes, invalid numeric separators, mixed
table declarations, and invalid date/time shapes are typed failures with source positions. Arrays
may contain mixed TOML values as allowed by TOML 1.0. Numeric and temporal values retain canonical
source text so parsing never rounds or applies a host timezone.
## Grill Log
- **Q:** Convert every number to `Float64` and time to a host instant? **A:** No. _Rationale:_ that
  loses exact configuration text and invents a zone for local values. _Rejected:_ JSON's smaller
  value model; last-key-wins duplicate handling; locale-sensitive parsing.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[Std Toml Read]] · [[Std Toml Scan]]
