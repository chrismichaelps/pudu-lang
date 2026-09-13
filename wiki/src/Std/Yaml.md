---
type: module
path: "@root/lib/Std/Yaml.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, yaml, configuration]
aliases: [Std Yaml]
---
# Std Yaml
## Purpose
Read the subset of YAML that configuration files are written in, refusing what it does not read
rather than guessing at it.
## Interface
Exports `Yaml` (text, whole and fractional numbers, truths, empty, lists, and mappings), `YamlError`,
`decode`, typed projections, field, index, and dotted-path lookup, key listing, and `explain`.
## Governance and algorithm
Block mappings and sequences, one-line flow mappings and sequences, quoted and plain scalars, `|` and
`>` block scalars, comments, and document separators are read. Anchors and aliases, explicit tags,
complex keys, and merge keys are refused, because each changes what a document means. Tabs in
indentation are refused. Fractional numbers are kept as written.

Lines are measured once, then blocks are read by indentation. Nesting is bounded: each indented block
costs a reader recursion and the evaluator bounds call depth, so a block that would open more than
512 levels deep answers `TooDeep` at its line instead of stopping the program.
## Grill Log
- **Q:** Skip anchors, tags, and merge keys that are not understood? **A:** No. _Rationale:_ a reader
  that skipped one answers with a document that is not the one written. _Accepted:_ refusal.
- **Q:** Let block nesting recurse until the evaluator's call limit? **A:** No. _Rationale:_ that
  limit stops the whole program, and a nested document is ordinary input. _Accepted:_ a 512-level
  bound answered as `TooDeep` at the opening line.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[Std Toml]]
