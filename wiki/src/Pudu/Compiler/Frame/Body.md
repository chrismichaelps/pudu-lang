---
type: module
path: "@root/src/Pudu/Compiler/Frame/Body.hs"
fidelity: Active
aliases: [Compiler Frame Body]
grammar: "[[grammar/haskell]]"
---
# Compiler Frame Body

## Purpose and interface

Lower every current Core statement/expression/control shape to flat blocks.
A Flow is Stopped or Completed with an optional payload. Normal unit/text
effects have no payload; Never is Stopped. Materialize unit only when a scalar
consumer/argument slot needs its sentinel. Discarded text/display keeps operand
effects without creating a fake text value; print handles literal/display
arguments directly. Snapshot every local read before later operand effects.
Logical operators use guarded blocks, eager operators use ordered scalar slots.
Calls allocate a resume label and optional result slot, then terminate the block.
Blocks, branches and loops preserve normal joins and abrupt paths. Loop targets
use CoreLoopId, with break values assigned only after their operands complete.
Stop after a terminator, preserving the earliest error/transfer. Do not render
source diagnostics or allocate runtime frames here.

## Invariants and failures

The contract in [[Native Execution Frames]] governs ordered effects, snapshots,
Never paths, call continuations and source provenance. The pure pass is separate
from allocation/failure policy and the future C dispatcher. No lower depth
limit, larger host stack, permanent refusal or interpreted fallback repairs
#499. The known integration regression remains red until dispatch is wired.

## Resolved Grill Log

- **Q:** May a call remain inside an emitted value expression? **A:** No; explicit suspension and a resume block are required.
- **Q:** Can a later argument re-read an earlier mutable operand? **A:** No; local reads produce snapshots before subsequent effects.
- **Q:** What does a Never path return? **A:** No payload and no continuation; subsequent instructions are not emitted.
- **Q:** Does pure control lowering choose memory-exhaustion behavior? **A:** No; that runtime boundary is resolved separately before allocator implementation.

## Dependencies and consumers

[[Pudu Core]] · [[Core Frame IR]] · [[Compiler Frame Lowering]] ·
[[Compiler Frame State]] · [[Compiler Frame Body]] · [[Native Execution Frames]]

## Grill Log

- **Q:** How are constructions and run-time failures lowered? **A:** A variant becomes `FrameConstruct` with its index and payload in declaration order; `CoreFailText` evaluates its message into a slot and ends the block with `FrameFailText`; `match` is lent to [[Compiler Frame Match]] (#525).

## Generic records (#552)

Pattern update only: `CoreRecordType` has an argument list.

## Closures (#555)

Resolved Grill Log: a closure's captures and a call through a value lower like
other operands, and the call checks its argument and result types against the
function type.

## Arrays and moves (#556)

Resolved Grill Log: arrays, their methods and indexing lower like other
operands; a take reads the local into a fresh slot with a move. Declarations,
assignments, break values and branch results move out of their temporaries.

## Computed help (#558)

`CoreFailText` lowers its help after its message, so both are evaluated before
the failure terminator.

## Referenced by

[[src/_MOC]] · [[Program Compiler Module Map]] · [[Native Frame Pressure Repair]]

## Floating values (#512)

`CoreFloatLiteral` saves a `FrameFloatLiteral`; float result slots exist for
calls, branches and loops like other scalars. Print of a floating display
emits `FramePrintSlot` on the float slot.

## Text values (#515)

Text literals now produce a slot when used as values; `lowerPrint` keeps the
literal and scalar-display fusions and otherwise prints a text slot.
`CoreDisplay` of a scalar saves `FrameDisplay`, of Str reads the operand;
`CoreShow` saves `FrameShow`.

## Text methods (#516)

`CoreTextMethod` lowers its arguments left to right, then its receiver, then
saves one `FrameTextMethod` value.

## Char values (#518)

Char literals and `CoreCharCode` save one value each; a Char call or branch
result gets a result slot like any scalar.

## Tuples (#521)

`CoreTuple` lowers its members as operands and saves one `FrameTuple`;
`CoreTupleIndex` saves `FrameTupleIndex`; tuple results get a result slot.

## Records (#521)

`CoreRecord` lowers its written fields, then saves `FrameAggregate` with the
slots in declaration order. `CoreRecordUpdate` lowers the base, then the
written fields, and fills the other members with `FrameMember` reads of the
base. `CoreField` saves `FrameMember` at the field's position.
