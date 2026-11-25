---
type: module
path: "@root/src/Pudu/Eval/UrlEncode.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Eval Url Encode]
---
# Eval Url Encode

## Purpose

The evaluator's `urlEncodeComponent(text)` builtin, implemented by `callUrlEncode`.

## Contract

Escapes exactly the bytes that [[Native URL Kernel]] escapes, by the same rule: unreserved bytes (ASCII letters, digits, `-`, `_`, `.`, `~`) are kept, and every other UTF-8 byte becomes `%` and two upper-case hexadecimal digits. A text with nothing to escape is returned unchanged. A non-text argument reports the builtin argument error.

## Resolved Grill Log

Why a kernel: the library version pushed one escape text per byte into an array and joined it, about 7% of the website module page's CPU; returning unchanged text without allocating keeps the common case free. The builtin is pure, so it counts as a hashing builtin and constants may fold through it.

## Referenced by

[[Native URL Kernel]]
