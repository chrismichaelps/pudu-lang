---
type: module
path: "@root/src/Pudu/Frontend/Syntax/Stored.hs"
fidelity: Active
domain: "[[Frontend]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: MEDIUM
tags: [module, medium, cache]
aliases: [Syntax Stored]
---

# Syntax Stored

## Purpose

The stored form ([[Cache Persist]]) of every [[Syntax Tree]] node, kept apart from the tree so the
tree's module holds its shapes alone.

## Governance

- Every node is stored the way its shape dictates, except a module's declarations and a function's
  body, which are stored as deferred blocks and read when first reached.
- The instances are orphans on purpose: the class knows nothing of syntax. Every module that stores
  or reads a tree imports this one; a missing import is a compile error, never a silent change.

## Linkage

- **Requires:** [[Syntax Tree]], [[Cache Persist]].
- **Consumed by:** [[Compiler Cache]].

## Referenced by

[[src/Pudu/Frontend/Syntax/_MOC]] · [[Syntax Tree]] · [[Compiler Cache]]
