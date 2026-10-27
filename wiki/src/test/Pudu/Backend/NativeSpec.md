---
type: module
path: "@root/test/Pudu/Backend/NativeSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, backend, conformance]
aliases: [Backend Native Tests, Native Conformance Tests]
---

# Backend Native Tests

Add UInt and fixed unsigned entry statuses, including the UInt64 maximum.
Resolved Grill Log: preserve IntValue reporting without signed narrowing; use
the existing differential status/output harness.

Extend entry-status cases for fixed signed results, including negative minimum,
positive 127 and values clamped to 255. Resolved Grill Log (#497): compare actual
native status/output with the existing IntValue CLI policy for every admitted kind.
Rename the integer property labels to cover both platform and fixed signed kinds;
the corpus and oracle assertions remain shared.

## Explicit frame emission (#499)

Compile checked Core through lowerFrames and emitProgram's typed result before
invoking the toolchain. The unchanged observable conformance assertions include
the wide recursion regression. Resolved Grill Log: faults fail the test before
compiling, with no recursive-emitter fallback or relaxed oracle comparison.

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
- Functions: helper functions with parameters, nested and sequenced calls,
  argument evaluation order (functions that print as they are called),
  unit-returning functions, early returns inside called functions, recursion,
  and mutual recursion — each run both ways and compared byte for byte.
- Regression corpus: [[Backend Function Programs]] supplies typed helpers, Unicode names, effect ordering, operand freezing, short-circuiting, recursion, mutual recursion, and exact depth-bound/reset cases.
- Loop control: [[Backend Control Programs]] compares scalar loop results, nested and labelled transfers, repeated labels, condition reevaluation and enclosing-condition transfers, break-operand transfers, Never joins, Never scalar operands, nested unit returns, unit-valued if-without-else, print/display transfers, short circuit, and discarded-value effects and arithmetic failures.
- Exit statuses: `0`, nonzero, values above 255, and negative results — the
  `reportResult` clamp on both sides.
- Refusal paths: division by zero (`E7004`) and overflow for `add`,
  `subtract`, `multiply`, `divide` (INT64_MIN / -1), and `negate` (`E7005`) —
  stdout, stderr text, and status 1 must all match, with the excerpt and
  caret rendered from the program's own source.
- Call depth: a program whose recursion passes the evaluator's bound aborts on
  both sides with the identical `E7002` rendering at the identical call span
  and exit status 1.
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
[[Backend Runtime]], [[Diagnostic Evaluation]], and the shared test
coordinator.

## Resolved Grill Log

- **Q:** How is milestone #488 protected against C evaluation-order drift? **A:** Pure checks assert reachable function signatures and refusal spans; execution checks compare nested calls, mutable operand snapshots, short-circuit effects, recursion, and depth-bound diagnostics against the interpreter.
- **Q:** May unsupported signatures pass because they are uncalled? **A:** Yes; reachability is the contract. A reachable unsupported signature refuses at its own construct, and an unreachable one never enters Core.

## Referenced by

[[Repository Test Runner]] · [[src/_MOC]] · [[src/Pudu/Backend/_MOC]] · [[Backend Toolchain]] ·
[[Backend Emit]] · [[Backend Runtime]] · [[Backend Emit Tests]]


## Solved native type inputs (#491)

Construct native facts from the root CompileResult used for the checked tree. Existing differential harness also executes inferred/aliased scalar signatures and annotated mutable locals, checking stdout, stderr, status and warning-free C.

Resolved Grill Log: consume canonical settled checker facts; preserve structural Never, print carrier refusals and existing runtime representations. Rejected: re-inference, display-name ABI selection, offset-only identity or silent fallback.

## Platform Int operators (#495)

Register integer success/refusal groups through the existing conformance function: actual tree evaluation versus compiled C stdout/stderr/status and zero warnings. Keep these groups distinct for focused runs.

Resolved Grill Log: boundary and failure matrices execute real native binaries; fixed repeated properties are not described as randomized sampling. Keep full numeric-family coverage pending.

The integer success harness accepts expected stdout and requires the interpreted stdout/stderr/status to equal it before differential comparison. Expected values use independent mathematical formulas in the corpus, not production integer kernels. Resolved Grill Log: two matching wrong results must still fail the gate.

## Exact integer entry status (#498)

Add an accepted deferred positive-2^63 entry result to statusPrograms; tree and
native must both clamp it to 255 with no extra value output. The integer corpus
also tests helper returns and local/branch/loop propagation of this value.
Resolved Grill Log: an internal carrier sign bit cannot reinterpret positive
2^63 as a negative exit result. Preserve reportResult's actual value semantics.

## Wide source admission (#507)

Extend entry status sources for Int128/UInt128 extrema, high unsigned values, 0/1/255/256 and deferred positive 2^127. Reuse the exact stdout/stderr/status oracle with both evaluator modes and mathematical integer matrices. Resolved Grill Log: no signed narrowing or extra entry-result rendering, no relaxed diagnostic comparison and no test module above 500 lines. [[Native Wide Source Admission]].

## Float conformance (#512)

Two groups run [[Backend Float Programs]]: success programs against their IEEE
answers and the interpreter, refusals against the interpreter's rendered
diagnostics.

## Text conformance (#515)

Two groups run [[Backend Text Programs]]: success programs against their
answers and the interpreter, refusals against the interpreter's diagnostics.

## Str method conformance (#516)

Two groups run [[Backend Text Method Programs]] against hand-written answers
and the interpreter's refusals.
