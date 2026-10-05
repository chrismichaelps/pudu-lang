---
type: module
path: "@root/test-fixtures/latealias/Lib/Sink.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, test]
---

# Late Alias Lib/Sink

## Purpose

Export a record naming later chained generic function aliases.

## Contract

Main checks without diagnostics and returns 0; the wrong callback reports E3001.

## Grill Log

- **Q:** Why keep the declaration order? **A:** Forming the record before the alias exposed the ordering defect; the fixture keeps that trigger.

## Referenced by

[[Type Interface Spec]]
