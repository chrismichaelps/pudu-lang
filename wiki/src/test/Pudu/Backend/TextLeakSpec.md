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

## Method lifetimes (#551)

Resolved Grill Log: include methodSuccessPrograms, so argument temporaries and
receivers holding text or boxes are released.

## Generic lifetimes (#552)

Resolved Grill Log: include genericSuccessPrograms.

## Try lifetimes (#553)

Resolved Grill Log: include trySuccessPrograms, so rebuilt failures and bound
payloads are released.

## For lifetimes (#554)

Resolved Grill Log: include forSuccessPrograms, so sequence values and states
are released.

## Closures (#555)

Resolved Grill Log: include closureSuccessPrograms, so closures and their captures are released.

## Array lifetimes (#556)

Resolved Grill Log: include arraySuccessPrograms, so moved, grown and copied
buffers are all released.

## Array patterns (#558)

Counts cleanup for [[Backend Array Pattern Programs]] too.

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

## Record programs (#521)

The counted run also covers [[Backend Record Programs]].

## Folded constants (#543)

Resolved Grill Log: include constantPrograms and use lowerModuleFolded with
compileFolded from the actual CompileResult. Count every allocation in nested
frozen text/aggregate construction, repeated reads and transfers; do not
synthesize constants or add an interpreter fallback to the native leak test.

## Shared reference lifetimes (#544)

Resolved Grill Log: include referenceSuccessPrograms in counted cleanup.
Existing frame-cell ownership must retain borrowed text and aggregate carriers
through parameters/results and release every allocation on completion.
