---
type: module
path: "@root/test/Pudu/Backend/EmitSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, backend]
aliases: [Backend Emit Tests]
---

# Backend Emit Tests

Move unsigned complement/parameter refusal fixtures to UInt128, retaining exact
checked-source refusal spans. Resolved Grill Log: newly admitted smaller kinds
are tested in the real corpus, and unsupported larger kinds still refuse.

For #497, replace newly supported narrow integer refusal fixtures with Int128
and unsigned forms. Resolved Grill Log: source remains checked and exact refusal
spans remain asserted; admitted narrow cases move into real conformance tests.

## Explicit frame emission (#499)

Run lowerFrames after structured Core inspection, then handle emitProgram's
Either result as located native refusal data. Hygiene checks require anonymous
frame slot access instead of legacy pudu_v C locals. Resolved Grill Log: inspect
the representation delta while preserving arithmetic/site assertions unchanged.

## Purpose and interface

`backendEmitProperties` pins the two promises of native compilation that are
pure functions of the source: lowering refuses exactly what the native subset
does not carry, and emission is deterministic and shaped as documented. It
runs in the ordinary suite, needs no C compiler, and never executes generated
code — [[Backend Native Tests]] owns execution.

## Behavior and dependencies

- Lowering: a supported program lowers to a module with the expected function,
  locals, statement shapes, and call shapes, and only functions reachable from
  the entry are carried — a declaration the entry cannot reach does not block
  the build and does not refuse, because the interpreter never runs it; each
  unsupported construct (a module without `main`, arrays, ownership-bearing break values,
  floats, `Str` locals, borrows, matches, function values and calls through
  local values, calls to the entry, parameters of unsupported types, default parameter values, unresolved inferred
  results, expression-bodied non-entry functions, and trailing or explicitly
  returned print results) lowers to a refusal whose
  code is `E6001` and whose span is the construct's own.
- Control-flow diagnostics: invalid enclosing labels and values carried out of a while loop remain semantic errors, before native lowering; structured codes and hasErrors are checked. The supported while expression is carried in CoreEvaluate as CoreWhileValue.
- If-without-else: Int, Bool and print-Result trailing branch values are accepted in unit value contexts after the interpreter correction in [[ADR-0025-if-without-else-unit-results]]. Ordinary escaped print results retain their separate explicit refusal.
- Divergence: entry bodies ending in `loop {}` or `return loop {}` pass the ordinary checker and native lowering. These acceptance tests never execute either infinite program.
- Emission: emitting the same core module twice yields identical text;
  emitting different sources at the same offsets does not confuse site
  excerpts; the generated translation unit contains one site per checked
  operation with the operation's own excerpt, no `#line`, only the approved
  standard/platform includes, and generated local names rather than source
  identifiers. [[Backend Native Tests]] checks function prototypes, wrappers,
  symbol portability, and operand/argument sequencing through compilation
  without warnings and observable differential execution.
- Diagnostics: `E7004`/`E7005` site entries carry the message and help text
  of [[Diagnostic Arithmetic]] verbatim and call sites carry [[Diagnostic
  Evaluation]]'s `E7002` text verbatim, so the native and interpreted texts
  are equal by construction and the differential tests then prove the
  renderers agree.

## Algorithm and negative logic

Programs must pass the ordinary compiler without error diagnostics before
lowering is tested, so refusals are about the real checked tree, not a
hand-made one. The suite asserts what is present and what is absent; it does not
snapshot the whole translation unit, because the runtime text changes for
reasons unrelated to any one check and a full snapshot would turn every
runtime edit into a test rewrite. Emission stability is asserted by
re-emission, and shape by targeted containment.

Uses [[Compiler Lower]], [[Compiler Lower Body]], [[Backend Emit]],
[[Diagnostic Arithmetic]], [[Diagnostic Evaluation]], [[Diagnostic Native]],
[[Compiler Pipeline]] and the shared test coordinator.

## Resolved Grill Log

- **Q:** How can a wholly divergent entry be tested safely? **A:** Compile and lower both trailing-loop and returned-loop forms, assert the entry is carried, and never run them. Their body-derived ABI has no observable successful result.
- **Q:** How is milestone #488 protected against C evaluation-order drift? **A:** Pure checks assert reachable function signatures and refusal spans; execution checks compare nested calls, mutable operand snapshots, short-circuit effects, recursion, and depth-bound diagnostics against the interpreter.
- **Q:** May unsupported signatures pass because they are uncalled? **A:** Yes; reachability is the contract. A reachable unsupported signature refuses at its own construct, and an unreachable one never enters Core.

## Referenced by

[[Repository Test Runner]] · [[src/_MOC]] · [[src/Pudu/Backend/_MOC]] · [[Backend Emit]] ·
[[Compiler Lower]] · [[Backend Native Tests]]


## Solved native type inputs (#491)

Every lowerProgram call supplies same-result settled facts. Previously refused inferred scalar parameter/result cases become accepted; unsupported formed types, generics and defaults still refuse at their source spans. Cover missing facts and canonical identity separately without weakening refusal expectations.

Resolved Grill Log: consume canonical settled checker facts; preserve structural Never, print carrier refusals and existing runtime representations. Rejected: re-inference, display-name ABI selection, offset-only identity or silent fallback.


## Unit literals and parameters (#492)

Replace the unit-parameter refusal with positive Core admission for a unit literal, unit parameter and unit result. Keep nonempty tuple and print Result refusals independent. Pure checks assert the signature instead of merely accepting any Core.

Resolved Grill Log: preserve the single unit inhabitant and every effect without allocating a new representation. Reject void-valued C initializers, Result erasure and omitted argument evaluation. Nonempty tuples remain pending; #493 implements unit display/equality.


## Unit display and equality (#493)

The unit signature acceptance case also carries unit display and equality. Explicitly preserve E6001 for unit ordering/arithmetic at the first operand; checker acceptance does not grant integer representation semantics.

Resolved Grill Log: unit has one value but its operands still execute. Reject skipped/repeated effects, void C initializers, wrong runtime printer selection and accidental ordered/arithmetic unit admission. Owned text representation and E7001 invalid-operation lowering remain separate obligations.

#493 carrier audit: explicit display and equality guards reject Core print carriers, including nested blocks/conditional values, before unit admission. Refusal regressions use checked Result-valued source, so print is never silently formatted or compared as unit. Genuine no-else unit boundaries remain admitted.


## Explicit scalar runtime refusals (#494)

Previously refused unit arithmetic/ordering now lower to explicit runtime traps; remove only those obsolete refusal entries. Preserve direct/nested print Result display/equality refusals and unsupported owned/numeric cases.

Resolved Grill Log: reproduce actual interpreter dispatch, canonical settled kinds, operand order and diagnostic spans; never classify print Result as unit or implement invalid operations as integer arithmetic. No syntax/inference change.

## Platform Int operators (#495)

Remove only obsolete platform Int bitwise/complement E6001 cases; replace with width-bearing Int8 cases so unsupported widths remain refused.

Resolved Grill Log: boundary and failure matrices execute real native binaries; fixed repeated properties are not described as randomized sampling. Keep full numeric-family coverage pending.

## Deferred literal no-loss guard (#498)

The interim partition added block/local positive-2^63 located refusals.
Revision 4 removes those entries in favor of successful native tests in
[[Backend Deferred Integer Programs]]. Existing integer success/refusal
matrices protect immediate negative minimum and nonliteral negation overflow.

Resolved Grill Log: the source must pass ordinary checking before native refusal
is asserted. This pins a representation boundary without changing the oracle or
pretending that full accepted-intermediate coverage is complete.

The function-value fixture previously expected a second refusal at chosen()
after its initializer helper had already failed. Under the resolved failed-block
policy, require one E6001 at helper and stop before the dependent call. Rename
the property to state that contract. The representation/unsupported-construct
assertions stay exact, including source positions; this is an inspected native
diagnostic recovery change, not a Pudu execution or checker change.

## Exact integer carrier integration (#498)

Remove the two interim deferred block/local E6001 entries because their
successful native behavior is now exercised in the deferred corpus. Preserve
other representation refusals and exact failed-block diagnostic recovery.

Resolved Grill Log: implement [[Exact Native Integer Carriers]] without changing the oracle. Preserve positive boundary values, exact diagnostic provenance, Never transfers, and warning-free helper selection. The internal carrier is not a public type-layout promise; full native coverage remains open.

## Signal header hygiene (#505)

Allow the standard C signal.h header required by process IO policy. Resolved
Grill Log: this is an inspected standard-header addition; preserve the closed
include whitelist and all extension/source-identifier/preprocessor checks.

## Wide source admission (#507)

Replace the newly admitted 128-bit refusal fixtures with reachable, ordinarily checked BigInt/Float32/Float64 parameter cases and exact marker spans. Preserve all remaining unsupported-construct and hygiene checks. Resolved Grill Log: success coverage moves to real source execution; do not remove negative representation coverage. [[Native Wide Source Admission]].

## Floats admitted (#512)

The Float32/Float64 parameter and floating-binding refusal fixtures now
compile, so they become Decimal parameter, Char parameter and decimal binding
cases with the same marker-span checks. Float success coverage lives in
[[Backend Float Programs]].

## Shadowed display refusal (#513)

A module `fn display(value: Int) -> Str` is resolved as the program's own
function, so lowering refuses its `Str` return type at that span instead of
printing the builtin rendering.
