---
type: module
path: "@root/test/Pudu/Backend/CharPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Char Programs]
---
# Backend Char Programs

## Purpose and interface

Export charSuccessPrograms :: [(String, Text, Text)] and
charRefusalPrograms :: [(String, Text)], run by [[Backend Native Tests]] and,
for successes, by [[Backend Text Leak Tests]].

## Coverage

Literals from ASCII, two-, three- and four-byte scalars, every escape `show`
treats specially plus control characters it leaves alone, ordering at U+0000
and U+10FFFF, `code` and `toText`, `charAt` on each width and at the last
index, Char through parameters, results, mutation, loops and branches, and
Char entry results including the quote and backslash cases.

Refusals: charAt past the end, at the length, negative, on empty text, with
operands that print first; Char arithmetic (`+`, `*`, `-`, `%`) and unary
`-`, each after its operands run.

## Grill Log

- **Q:** Where do the answers come from? **A:** Written by hand, so the
  interpreter and native cannot agree on a shared mistake.

## Referenced by

[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Native Char Runtime]] · [[src/_MOC]]
