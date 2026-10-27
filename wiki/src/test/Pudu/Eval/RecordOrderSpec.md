---
type: module
path: "@root/test/Pudu/Eval/RecordOrderSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, runtime]
aliases: [Eval Record Order Tests]
---

# Eval Record Order Tests

## Purpose and interface

Export recordOrderProperties. Each program runs through the tree walker and
with compiled bodies (`PUDU_EVAL`), and both must give the same answer.

## Coverage

A record literal, a record-payload variant and an update written out of
declaration order render and compare as declared; a failing field shows the
fields still run in written order; a record pattern reads a reordered record;
a record built by a function called from a pure loop goes through the loop
kernel's closed region.

## Grill Log

- **Q:** Why drive both evaluators? **A:** The tree walker, compiled bodies and
  the loop kernel each build records themselves; the bug was in all three.

## Referenced by

[[Eval Env]] · [[test/Main]] · [[src/_MOC]]
