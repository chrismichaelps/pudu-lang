---
type: module
path: "@root/src/Pudu/Eval/Loop/Unboxed.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance]
aliases: [Eval Loop Unboxed]
---

# Eval Loop Unboxed

## Purpose and interface

A machine-word fast path for a proven pure while-region whose condition and body
plan entirely into the platform-signed integer grammar, and whose initial
bindings are all platform `Int` values. [[Eval Loop Kernel]] offers the planned
region to this module and uses it only when every eligibility condition holds;
otherwise the existing boxed kernel executes unchanged. Both computation paths
share one admission proof, one commit, and one set of diagnostics, so the
unboxed path is an execution-representation choice inside the kernel, never a
semantic mode or a workload recognition.

Measured on GHC 9.10.3/aarch64: the Loop workload drops from 560/555 ms
(tree/compiled) to 245/246 ms with allocation from 2,334 MB to 2 MB and no
other workload, output or suite check changed. The remaining cost is closure
dispatch per iteration, so the cut is real but native-parity millisecond
performance still requires native emission and no promotion is claimed.

## Algorithm and invariants

Region bindings live in a single unboxed `MutableByteArray#` with 64-bit
element-indexed `readInt64Array#`/`writeInt64Array#` access; the planner never
reads binding values, only their positions. Integer arithmetic uses checked
machine carry flags (`addIntC#`, `subIntC#`), a wrapped-product/divisor
roundtrip check for multiplication, and pinned `quotInt#`/`remInt#` with
explicit zero and minBound/-1 refusals, so every refusal reproduces the boxed
helper's E7004/E7005 text and span through the shared `abortAt` builder.
Comparisons and
negation read as `Int#` 0/1 conditions via `Int64#` comparisons; logical
operators keep short-circuiting. Evaluation is strictly left to right; each
step's refusal ends the region immediately with no state exposed. Exactly one
`IntValue PlatformSigned` is boxed per written binding at exit, committed in
the same names/positions order as the boxed kernel, and only after a fully
successful exit. The constant step-limit boundary (E7002) uses the same
threshold and loop span, checked once per iteration at the loop top.

## Failures and negative logic

Any unsupported syntax, non-platform integer kind (suffix widths, BigInt),
float, index, member, record, call, effect, transfer, declaration, break/return
or nested loop rejects the entire region at plan time and the boxed kernel runs
instead; a runtime initialization mismatch (any binding not a platform `Int`)
demotes to the boxed execution after the same admission checks. No source name,
benchmark size, or trip count enables or steers the path. Failure diagnostics
are produced by the same shared abort helpers with the original spans, so an
aborting program sees byte-identical codes, messages and help.

## Dependencies and consumers

Requires [[Eval Env]] spans and kind lookup, [[Eval Match]] literal decoding,
[[Integer Literal]] kind names, [[Compile Time Limits]] for the iteration
boundary, and GHC unboxed primops. Consumed only by [[Eval Loop Kernel]].

## Grill Log

- **Q:** Why a second execution representation inside the kernel? **A:** The
  measured dependency profile attributes the Loop workload entirely to
  `Pudu.Eval.Loop.Kernel` (2.16 GB ticky, ~27 closures per iteration, 778
  bytes allocated per iteration), so per-scalar `Value` boxing, not syntax
  dispatch, is the measured cost. _Rejected:_ profile-guided special-casing of
  benchmark names, and changing public evaluation semantics.
- **Q:** Why not keep the boxed `scalar`/`checkedResult` helpers for exact
  semantics? **A:** Their observable contract is the diagnostic, not the box.
  The unboxed path reuses the same abort builder and kind names so refusal
  text and spans are identical; the focused fixture pins E7004/E7005/E7002
  and the full suite runs the same programs under both paths.
- **Q:** Why 64-bit slots instead of `Int#` array primops? **A:** GHC 9.10 has
  no checked `Int64#` arithmetic and its signed comparisons are `Int64#`-typed
  (`ltInt64#`…); keeping arithmetic as machine `Int#` with carry flags and
  converting only at reads/writes/comparisons keeps one representation with no
  silent widths. _Rejected:_ `unsafeCoerce`-style width punning.
- **Q:** Why refuse minBound/-1 division explicitly? **A:** `quotInt#` of the
  extreme pair is undefined at the machine level (hardware trap risk), while
  the boxed path computes the exact Integer quotient and refuses E7005
  ("divide"). The explicit pin reproduces the refusal and never executes the
  trap.
- **Q:** Does the step limit still apply? **A:** Yes; checked at the loop top
  with the same threshold and span, unconditionally when effects are not
  admitted, so constant evaluation refuses exactly as before.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[src/_MOC]] · [[Eval Loop Kernel]] · [[Eval Loop Step]] ·
[[Performance Constitution]] · [[Backend Performance Delivery]]
