---
type: module
path: "@root/test/app-layers.test.mjs"
fidelity: Active
tags: [test, application, graph]
aliases: [Application Layer Tests]
---
# Application Layer Tests

## Purpose and algorithm

Exact graph fixtures verify valid direction, upward imports, missing dependencies, unclassified
modules, duplicate identities, self and multi-module cycles, masked comments and literals, stable
report order and long dependency chains. The actual shipped library passes the command's path
and complete-graph checks. Temporary invalid library roots exercise unsuccessful command output.

## Resolved Grill Log

- **Q:** Check only the current graph? **A:** No; deliberate defect fixtures prove every refusal.
- **Q:** Accept a stable success code with missing files? **A:** No; exercise empty and invalid roots.

## Referenced by

[[Application Layer Model]] · [[Application Layer Gate]] · [[src/_MOC]]

The challenge admission layer sits above wire preparation and below Session. Pin the resulting upward-edge diagnostic, including the hosting layer number. Resolved Grill Log: exact-output expectations change only with the inspected architectural catalog delta.
