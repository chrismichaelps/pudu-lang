---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileControls.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native]
aliases: [Uses Mobile Controls]
---

# Uses Mobile Controls

## Purpose and interface

Stdlib fixture for the value controls of [[Std Mobile Control]], the event decoding of [[Std Mobile Decode]] and the instructions of [[Std Mobile Stream]] that carry them. Its entry drives `build`, `revise`, `bits`, `mount` and `update` through the checks below and answers the number of checks that held. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count.

The entry has thirteen checks and answers `13`. The data spec `DataSpec.hs` runs it.

Checks:
1. The stream words of each control's build: CREATE with its kind, TAG, then the bounds, options, count or moment, then the value or selection, in that order.
2. The stream words of each control's revise: a changed value alone writes one value instruction; a changed bound or option list writes its instruction and rewrites the value after it; an unchanged control writes nothing.
3. Replacement: a change of tag or of variant replaces the node. The `Control` wrapper in [[Std Mobile View]] builds the new node and removes the old one.
4. Decoding of `Valued`, `Colored` and `Dated`, including a negative date and a word list shorter than two words, which reads as `Stopped`.
5. `bits` round trips: a signed value written by `bits` and read back by `signed` gives the same value.

The fixture runs interpreted and as native C11 code, and both must agree.

## Invariants

- Each check compares an exact word or byte sequence, never a length alone.
- The fixture makes no foreign call. The host side of each control is checked by the simulator run of [[Native Controls Example]], not here.

## Negative Logic

- No platform host is started, so the fixture runs without a simulator.
- No check of a symbol's availability. An unknown symbol is not a defect and is not checked as one.
- Decoding is checked on the values the host would write, not on a live event.

## Dependencies and consumers

Depends on [[Std Mobile Control]], [[Std Mobile Decode]], [[Std Mobile Stream]] and [[Std Mobile View]]. Its checks mirror the contracts that [[iOS Host Values]], [[iOS Host Text]] and [[iOS Host Kinds]] realize.

## Resolved Grill Log

- **Q:** Check bytes or summaries? **A:** Exact words, as for [[Uses Mobile View]]. A summary such as "contains a value instruction" would pass a wrong value or a wrong node id.
- **Q:** Why check a changed field alone? **A:** A change to one field must write exactly that one instruction. A combined check would hide a commit that rewrote the whole control.

## Referenced by

[[Native iOS Controls Delivery]]
