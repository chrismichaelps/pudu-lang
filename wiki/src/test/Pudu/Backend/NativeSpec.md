---
type: module
path: "@root/test/Pudu/Backend/NativeSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, backend, conformance]
aliases: [Backend Native Tests, Native Conformance Tests]
---

# Backend Native Tests

## Purpose and interface

`backendNativeProperties` holds native execution to the tree interpreter, byte
for byte: for each conformance program it runs the program in-process through
the evaluator and as a real compiled executable through [[Backend Toolchain]],
and compares standard output, rendered diagnostic text, and exit status. This
is the test that makes "the interpreter is the semantic oracle" a checked fact
rather than a design intention.

## Behavior and dependencies

- Success paths: arithmetic and comparisons, `if`/`else` values, `while`
  loops with accumulating locals, early `return`, `print` of integers,
  booleans, string literals, and `display(...)`.
- Exit statuses: `0`, nonzero, values above 255, and negative results — the
  `reportResult` clamp on both sides.
- Refusal paths: division by zero (`E7004`) and overflow for `add`,
  `subtract`, `multiply`, `divide` (INT64_MIN / -1), and `negate` (`E7005`) —
  stdout, stderr text, and status 1 must all match, with the excerpt and
  caret rendered from the program's own source.
- Toolchain paths: missing compiler, a scripted compiler that fails to start,
  a scripted compiler that hangs past `PUDU_CC_TIMEOUT`, a scripted compiler
  that rejects the C, and an unwritable output path — each maps to its
  `E6002`–`E6006` diagnostic.
- Generated C is asserted warning-free under the fixed flag policy.

The interpreter side runs `evaluateProgramEntryFolded` with standard output
redirected to a capture file and renders diagnostics with the interpreter's
own renderer; the native side runs the published executable with
`readProcessWithExitCode`. Both sides use the same exit-status arithmetic,
mirrored from the `pudu` executable's `reportResult` in one documented
helper.

## Algorithm and negative logic

Programs are written to a fresh temporary directory as files whose names
match their module names — the compiler's own stem rule — so the conformance
run is an ordinary build of an ordinary program, not a special path. When no
C compiler is found the execution checks are skipped with an explicit note;
they are never silently passed. The missing-compiler check hides the compiler
by pointing `PATH` at an empty directory, because an empty `PATH` makes
discovery throw rather than answer. Colour is off in both capture paths, so
the comparison is plain text by construction, and the exit-status clamp is
checked at its boundaries rather than sampled.

Uses [[Compiler Pipeline]], [[Evaluator]] entry evaluation, [[Diagnostic
Render]], [[Compiler Lower]], [[Backend Emit]], [[Backend Toolchain]],
[[Backend Runtime]], and the shared test coordinator.

## Referenced by

[[Repository Test Runner]] · [[src/_MOC]] · [[src/Pudu/Backend/_MOC]] · [[Backend Toolchain]] ·
[[Backend Emit]] · [[Backend Runtime]] · [[Backend Emit Tests]]
