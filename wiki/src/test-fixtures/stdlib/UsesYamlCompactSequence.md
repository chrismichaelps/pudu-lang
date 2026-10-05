---
type: module
path: "@root/test-fixtures/stdlib/UsesYamlCompactSequence.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, yaml]
aliases: [Uses Yaml Compact Sequence]
---

# Uses Yaml Compact Sequence

## Purpose and interface

`main` returns zero after exact structural assertions for compact sequences inside list mappings,
first and subsequent keys, nested navigation items, sibling keys and outer items, explicit indentation,
empty keys, the 512-level nesting boundary and the exact TooDeep line, and a tab-indentation failure. A mismatch panics with the input document.

## Grill Log

- **Q:** Test only that decoding succeeds? **A:** No. _Rationale:_ the regression succeeded while
  dropping values. _Accepted:_ exact complete value comparisons and an explicit failure case.

## Referenced by

[[Std Yaml]] · [[Protocol Evaluation Spec]]
