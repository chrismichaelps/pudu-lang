---
type: module
path: "@root/test/Pudu/Backend/EmitSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, backend]
aliases: [Backend Emit Tests]
---

# Backend Emit Tests

## Purpose and interface

`backendEmitProperties` pins the two promises of native compilation that are
pure functions of the source: lowering refuses exactly what the native subset
does not carry, and emission is deterministic and shaped as documented. It
runs in the ordinary suite, needs no C compiler, and never executes generated
code — [[Backend Native Tests]] owns execution.

## Behavior and dependencies

- Lowering: a supported program lowers to a module with the expected function,
  locals, and statement shapes, and only the entry function is emitted — a
  declaration the entry cannot reach does not block the build, because calls
  are refused and it is unreachable; each unsupported construct (imports, a
  module without `main`, patterns, `break`, floats, suffixed integers, `Text`
  locals, borrows, matches) lowers to a refusal whose code is `E6001` and
  whose span is the construct's own.
- Emission: emitting the same core module twice yields identical text;
  emitting different sources at the same offsets does not confuse site
  excerpts; the generated translation unit contains the runtime prologue, one
  site per checked operation with the operation's own excerpt, and no
  `#line`, no nonstandard extension, and no source identifier used as a C
  identifier.
- Diagnostics: `E7004`/`E7005` site entries carry the message and help text
  of [[Diagnostic Arithmetic]] verbatim, so the native and interpreted texts
  are equal by construction and the differential tests then prove the
  renderers agree.

## Algorithm and negative logic

Programs are compiled from source strings through the ordinary compiler
before lowering, so refusals are about the real checked tree, not a hand-made
one. The suite asserts what is present and what is absent; it does not
snapshot the whole translation unit, because the runtime text changes for
reasons unrelated to any one check and a full snapshot would turn every
runtime edit into a test rewrite. Emission stability is asserted by
re-emission, and shape by targeted containment.

Uses [[Compiler Lower]], [[Backend Emit]], [[Diagnostic Arithmetic]],
[[Diagnostic Native]], [[Compiler Pipeline]] and the shared test coordinator.

## Referenced by

[[Repository Test Runner]] · [[src/_MOC]] · [[src/Pudu/Backend/_MOC]] · [[Backend Emit]] ·
[[Compiler Lower]] · [[Backend Native Tests]]
