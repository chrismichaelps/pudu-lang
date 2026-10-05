---
type: module
path: "@root/test/Pudu/Type/Check/PatternSpec.hs"
fidelity: Active
subsystem: "[[Testing]]"
grammar: "[[grammar/haskell]]"
tags: [module, test]
aliases: [Type Check Pattern Spec]
---

# Type Check Pattern Spec

## Purpose

Prove match coverage, unreachable-arm warnings, and matching through borrows.

## Interface

`patternProperties` contributes the coverage and borrowed-pattern test groups to the runner.

## Algorithm

Compile complete Pudu modules and dependency graphs and compare exact ordered diagnostics; check missing tuple combinations with the E5001 span, message, and help contract.

## Negative Logic

No snapshots, accepted guarded coverage, or independent-column coverage assumptions.

## Edge Cases

Tuple Option products cover all four combinations, grouped wildcard rows, nested tuples, alternatives, open payloads, and guarded missing combinations. Diagonal-only rows and literal-only payloads remain incomplete.

## Grill Log

- **Q:** How is namespace independence proved? **A:** Compile and run the complete borrowed nested Option classifier beside Std.Json through both direct and indirect dependency graphs, and reject a match missing one local Atom variant. _Rationale:_ both sums declare Null, Boolean, and Text, so a global constructor table is observably wrong (#378).

- **Q:** How is tuple coverage distinguished from an unsound independent-column union? **A:** Test both a complete correlated matrix and diagonal-only rows. _Rationale:_ both examples cover every individual column but only the first covers every tuple. _Rejected:_ success-only coverage tests (#377).

## Referenced by

[[Type Exhaust]] · [[Type Check Pattern]] · [[src/Pudu/Type/_MOC]]
