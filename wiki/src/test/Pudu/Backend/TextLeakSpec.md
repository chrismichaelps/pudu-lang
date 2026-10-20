---
type: module
path: "@root/test/Pudu/Backend/TextLeakSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Text Leak Tests]
---
# Backend Text Leak Tests

## Purpose and interface

Export textLeakProperties. Each [[Backend Text Programs]] success program is
lowered, emitted and built with `malloc`, `calloc` and `free` replaced by
counting wrappers; an `atexit` check fails the process if any block is still
live. Output must still equal the expected answer.

## Grill Log

- **Q:** Why count blocks instead of using LeakSanitizer? **A:** LeakSanitizer
  is not available on the macOS host, and a count also covers GCC builds.
- **Q:** Why `-Wno-unused-function`? **A:** Programs that never allocate text
  leave the counting `malloc` unused; the generated program itself is still
  checked warning-free by the native harness.

## Referenced by

[[Backend Text Programs]] · [[Native Text Runtime]] · [[src/_MOC]]

## Method programs (#516)

The counted run also covers [[Backend Text Method Programs]], so views that
retain their source and the text built by repeat, reverse, escapeHtml and
replace are all released.

## Char programs (#518)

The counted run also covers [[Backend Char Programs]], so the text that
display, show and toText build from a Char is released.

## Tuple programs (#521)

The counted run also covers [[Backend Tuple Programs]], so boxes and the text
they hold are released.
