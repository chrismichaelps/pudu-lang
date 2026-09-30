---
type: module
path: "@root/test-fixtures/latealias/RejectsWrongCallback.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, test]
---

# Late Alias RejectsWrongCallback

## Purpose

Refuse an Int callback where the imported later alias requires a Report reference.

## Contract

Main checks without diagnostics and returns 0; the wrong callback reports E3001.

## Grill Log

- **Q:** Why keep the declaration order? **A:** Forming the record before the alias exposed the ordering defect; the fixture keeps that trigger.

## Referenced by

[[Type Interface Spec]]
