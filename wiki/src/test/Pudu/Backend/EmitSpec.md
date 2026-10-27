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

Resolved Grill Log: preserve the single unit inhabitant and every effect without allocating a new representation. Reject void-valued C initializers, Result erasure and omitted argument evaluation. Unit display/equality and nonempty tuples remain separate pending boundaries.
