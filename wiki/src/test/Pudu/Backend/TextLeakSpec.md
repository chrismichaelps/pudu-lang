---
type: module
path: "@root/test/Pudu/Backend/TextLeakSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Text Leak Tests]
---
# Backend Text Leak Tests

Word-map algebra (#810): include successes in comprehensive and focused
counted groups. Resolved Grill Log: owned keys, input reuse, closures and
balanced result trees must all return live allocations to zero.

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

## Text collections (#559)

Counts cleanup for [[Backend Text Collection Programs]], arrays of views
included.

## Conversions (#560)

Counts cleanup for [[Backend Convert Programs]].

## Maps and sets (#561)

Counts cleanup for [[Backend Keyed Programs]], tree nodes included.

## Shapes (#563)

Counts cleanup for [[Backend Shape Programs]]' single-module programs.

## Range values (#564)

Counts cleanup for [[Backend Range Programs]].

## Bytes (#565)

Counts cleanup for [[Backend Bytes Programs]].

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

## Focused byte cleanup

Resolved Grill Log: the Bytes-only counted-allocation property reuses the
existing instrumentation and explicit expected outputs, selected with
`PUDU_TEST_MATCH="native Bytes"`. The comprehensive cleanup property remains.

## Output Results (#566)

Resolved Grill Log: Register focused output cleanup. Extend the reusable counted harness to accept expected stderr alongside stdout while retaining all existing corpora and assertions.

## Expression bodies (#567)

Resolved Grill Log: Register a focused counted expression-body corpus and include it in the existing complete owned-value corpus.

## Named callable dispatch (#568)

Resolved Grill Log: Add the named callable success corpus to the full owned-value lane and its dedicated focused allocation property.

The focused named-callable cleanup lane includes the existing closure corpus,
so hidden-environment ownership is verified beside direct named targets.

## First-class output builtins (#569)

Resolved Grill Log: Register focused counted output-callable programs with explicit stdout/stderr and include them in the comprehensive output cleanup lane.

A reusable optional C setup runs after the allocation-check atexit hook is
installed and before source entry. The failed-Result property replaces each
standard output with a pipe without readers, then requires zero live
allocations after repeated Err values. This POSIX-only boundary is explicitly
reported as pending on Windows. Existing healthy corpora use empty setup.

## BigInt (#800)

BigInt successes also run under counted allocation.

## Decimal (#802)

Decimal's library-free success also runs under counted allocation.

## Focused folded constant cleanup (#808)

Register a focused native folded-constant allocation group over constantPrograms.
Resolved Grill Log: keep the existing comprehensive group and count nested
owned data, repeated reads, updates and returns with exact expected output.
Decimal's library-free successes also run under counted allocation.

## Decimal callable cleanup (#806)

Add a focused native Decimal allocation group over decimalLeakPrograms;
the comprehensive allocation corpus continues to include it. It covers
owned Decimal arguments, Option payloads, closures and text parsing via
primitive values. Resolved Grill Log: use the existing malloc/calloc/free
instrumentation and exact output checks, with no library import or fallback.

## Native byte views (#827)

Include [[Backend Text View Programs]] in full and focused counted cleanup. Shared slices, Option payloads, closures and scalar tuples must return every allocation to zero. See [[Native Text Views]].

## Indexed stores (#840)

Count allocations over storeSuccessPrograms. Resolved Grill Log: the harness compiles one module, so library-importing programs are covered by differential runs only.

## Host services and type abstractions (#846)

Count allocations over `hostCountedPrograms` and abstraction successes.
Resolved Grill Log: task, scope, file and thread programs that own resources
run only through the counted harness; programs that would wait or touch the
network stay out of it.
