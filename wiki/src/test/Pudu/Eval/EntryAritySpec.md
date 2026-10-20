---
type: module
path: "@root/test/Pudu/Eval/EntryAritySpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, runtime]
aliases: [Eval Entry Arity Tests]
---

# Eval Entry Arity Tests

## Purpose and interface

Export entryArityProperties: a program whose `main` takes a parameter runs to
one E7003 diagnostic at the name `main`, and evaluation throws nothing.

## Grill Log

- **Q:** Why catch ErrorCall? **A:** The failure being guarded against is an
  uncaught `error`; without the catch a regression would kill the whole suite
  instead of failing this property.

## Referenced by

[[Eval Program]] · [[test/Main]] · [[src/_MOC]]
