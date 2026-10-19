---
type: module
path: "@root/src/Pudu/Backend/Emit/Support.hs"
fidelity: Active
domain: "[[Core IR]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
aliases: [Backend Emit Support]
tags: [module, backend, codegen]
---
# Backend Emit Support

## Purpose

Own the integer spelling the frame emitter shares: helper names for wide kinds,
C descriptors for an integer kind, exact integer literals and zero values.

## Interface

Exports isWideInteger, integerHelper, zeroValue, integerKindText and
integerLiteralText.

## Algorithm and invariants

Integer constants preserve exact sign and magnitude through UINT64_C compound
literals; wide values split into two 64-bit words plus a sign flag. A kind
without a 1..64-bit width and bounds has no narrow descriptor, and callers
refuse rather than guess one.

## Negative logic

No frontend or evaluator dependencies, IO, environment reads, or semantic inference.
Only lowered Core IR reaches this boundary. Source text never becomes executable C.

## Dependencies and consumers

Uses [[Pudu Core]], [[Integer Literal]], and [[Backend Emit State]]. Consumed by [[Backend Frame Program]], [[Backend Frame Bodies]] and [[Backend Frame Values]].

## Grill Log

- **Q:** Why extract this responsibility? **A:** It has a stable pure interface and keeps the emitter below 500 lines. The split preserves output ordering and diagnostic geometry. Rejected: a single growing emitter.
- **Q:** May extraction change semantics? **A:** No; eager evaluation is sequenced by the emitter, while this module supplies representation and assembly primitives. Rejected: backend inference.

## Referenced by

[[Backend Emit]] · [[src/Pudu/Backend/_MOC]]

## Resolved control-flow traversal (#489)

Runtime requirements visit both loop conditions and bodies and every break operand. Never is representation-free at the public function boundary and uses an initialized dummy integer only in unreachable scalar sequencing; no ownership-bearing value is admitted.

- **Q:** Can breaking with a discarded checked value omit its helper? **A:** No; the runtime walk includes the operand even when no result slot exists. Rejected: visiting only value-producing consumers.


## Unit display and equality (#493)

Select print_str for CorePrint of CoreDisplay whose operand type is CoreUnitType. Continue walking operand effects and wrappers. Unit display must not select an unused integer printer or omit the string printer.

Resolved Grill Log: unit has one value but its operands still execute. Reject skipped/repeated effects, void C initializers, wrong runtime printer selection and accidental ordered/arithmetic unit admission. Owned text representation and E7001 invalid-operation lowering remain separate obligations.


## Explicit scalar runtime refusals (#494)

CoreOperatorFailure visits all ordered operands and selects site, colored and fail runtime parts. Add no unused arithmetic helper or new runtime implementation.

Resolved Grill Log: reproduce actual interpreter dispatch, canonical settled kinds, operand order and diagnostic spans; never classify print Result as unit or implement invalid operations as integer arithmetic. No syntax/inference change.

## Platform Int operators (#495)

Select bitwise/wrapping helper plus from_bits; saturation selects only its helper; shifts select from_bits plus their helper and checked site/colored/fail dependencies. CoreComplement recursively visits its operand and selects bit_not/from_bits.

Resolved Grill Log: use defined unsigned bit patterns, validate counts before shifts, and prove signed arithmetic bounds before evaluation. The actual interpreter determines results, effect order and exact diagnostic vocabulary. No syntax or type-inference change.

## Exact integer carrier integration (#498)

Use pudu_int for integer declarations, prototypes and wrappers. Export
zeroValue :: CoreType -> Text and integerKindText :: IntegerKind -> Maybe Text.
Integer literals use compound literals with UINT64_C(abs value) and sign;
limits use canonical integerKindBounds/Width/Signed facts. No signed cast.
Close runtime part dependencies transitively with a visited set. Always carry
the type-only integer_value ABI declarations; integer comparisons add compare.
Do not select unused arithmetic/conversion functions. Other scalar paths stay
unchanged; source types are not inferred here.

Resolved Grill Log: implement [[Exact Native Integer Carriers]] without changing the oracle. Preserve positive boundary values, exact diagnostic provenance, Never transfers, and warning-free helper selection. The internal carrier is not a public type-layout promise; full native coverage remains open.

The descriptor projection supports bounded widths 1..64 and the separate 128-bit ABI; other widths return Nothing. The emitter treats that as an internal phase-contract violation; admitted source kinds are validated in lowering, with no guessed ABI.

## Wide frame bridge (#506)

Export isWideInteger and integerHelper. Width 128 selects wide_ helpers, pudu_wide_int declarations/results and typed zeros; descriptors use pudu_wide_kind. Literals carry both unsigned words of the value modulo 2^128 and an independent actual-negative flag. Runtime selection includes wide type-only declarations even for literal/read-only values, and uses the operand kind for Bool comparisons. Resolved Grill Log: retain the narrow path byte spelling, reject other widths, never narrow sign/high words, and keep legacy runtimeNeeds accurate. [[Native Wide Frame Bridge]].

## General runtime prerequisites (#511)

Use [[Native Runtime Dependencies]] for the existing cycle-safe closure walk.
No selection/representation policy changes here yet. Resolved Grill Log: retain
integer behavior while enabling actual floating prerequisites in later emission.

## Unused direct-emitter helpers removed (#512)

runtimeNeeds, entryResultType, prototypes, depth wrappers, function and local
symbols, declarations and comments belonged to the emitter that frames
replaced; nothing imported them. They are deleted rather than extended with
floating cases. The earlier sections record their history.

Resolved Grill Log: keep only what the frame emitter calls. _Rejected:_
growing dead code so a pattern match stays total.
