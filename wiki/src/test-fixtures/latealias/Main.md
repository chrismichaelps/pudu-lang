---
type: module
path: "@root/test-fixtures/latealias/Main.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, test]
---

# Late Alias Main

## Purpose

Check and run an imported record callback whose alias is declared later.

## Contract

Main checks without diagnostics and returns 0; the wrong callback reports E3001.

## Grill Log

- **Q:** Why keep the declaration order? **A:** Forming the record before the alias exposed the ordering defect; the fixture keeps that trigger.

## Referenced by

[[Type Interface Spec]]
