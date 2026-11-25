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
- **Q:** Why borrow at the operation instead of eliminating copies afterwards? **A:** The copy exists only because lowering asked for a fresh slot; an operation that never keeps its operand can read the local's own slot, and the ordering rule makes that sound without an analysis pass. A builder loop of five attribute sets per node went from 0.77 s to 0.71 s.

## Dependencies and consumers

[[Pudu Core]] · [[Core Frame IR]] · [[Compiler Frame Lowering]] ·
[[Compiler Frame State]] · [[Compiler Frame Body]] · [[Native Execution Frames]]

## Borrowed operands (#1008)

- `lowerBorrowed`: an operand an operation only reads, such as a field or tuple read, a conversion, a unary operator, or a rendered value, is a local read in its own slot, with no copy to retain and release. Any other operand, and a unit-typed local, lowers as before.
- `lowerOperandsBorrowing`: binary operators (other than the short-circuit ones) and a text method's receiver and arguments read a local operand in place only when every operand after it is a literal or a local read, so nothing evaluated later can assign it first. This is the rule array indexing already follows.
- Calls keep copying, since a call argument held in a `$taken` slot is transferred to the callee.


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

## Integer conversion (#560)

The conversion shapes lower their operand, then become one frame value.

## Maps and sets (#561)

Keyed operations lower their receiver before arguments, as array
methods do; a map or set result gets a slot like any box.

## Char from a code (#562)

`CoreCharOfCode` lowers its operand into one frame value.

## Range values (#564)

A range value lowers its present ends in order; range operations lower their
receiver before arguments.

## Bytes (#565)

Byte operations lower their receiver before arguments.

## Foreign calls (#850)

`CoreForeignCall` lowers its arguments to slots in order, then to `FrameForeign`; a stopped argument stops the call.

## Resolved Grill Log for #876 — Native callback lowering

Lower a callback operation after its operand. Allocate a callback token
result slot without borrowing a foreign-handle cell.

## Resolved Grill Log for #877 — Post-call settlement

Compile settlement as an ordinary unit frame store with effects, so it executes after the writeback statements.

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

`CoreTextMethod` lowers its receiver and then its arguments left to right, then
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

## Output Results (#566)

Resolved Grill Log: CoreOutputError lowers its operand once into a FrameOutputError text value. It has an ordinary owned result slot and never becomes an effect-only print. See [[Native Output Results]].

## First-class output builtins (#569)

Resolved Grill Log: Project CoreRuntimeKind over one evaluated operand to FrameRuntimeKind with an owned text result.

## Caller failures (#631)

CoreFailCaller lowers its message to a slot, then finishes the block with
FrameFailCaller. A message that stops stops the block first.
Resolved Grill Log: same order as CoreFailText; no help expression, since the
builtins that need it have constant help.

## Absent arguments (#638)

CoreAbsent lowers to a FrameZero value. Resolved Grill Log: no ownership is
created; the slot holds nothing to release.

## Decimal (#802)

Decimal literals and methods lower to their frame values; a Decimal result gets a slot.

## Indexed stores (#840)

A store result takes a fresh result slot. Resolved Grill Log: same rule as every boxed collection.

## Foreign handles (#853)

Foreign calls retain the whole checked crossing and claim metadata through frame lowering, and handle results occupy owned slots.

## Byte literals (#887)

`CoreBytesLiteral` lowers to a single `FrameBytesLiteral` value.

## Stored callable dispatch (#956)

Resolved Grill Log: Lower the closure operand before testing its target. A stopping operand transfers before the test.

## Runtime layouts in products (#956)

Resolved Grill Log: A record update may construct a widened layout. Fields copied from the base keep their types. Replacements must match the target field carrier.

## Runtime layouts in sum payloads (#956)

Resolved Grill Log: Validate each selected variant payload against its physical layout before emitting its slots.

## Local array indexing

Resolved Grill Log: An integer literal or local integer read cannot modify
the array owner. Read a local array's frame slot directly for that index.
An effectful index keeps the ordinary receiver snapshot. The lookup still
owns any returned element and uses the same bounds and diagnostic path.

Resolved Grill Log: a call argument lowered from a local move is a transferred
argument; its slot is the moved temporary. [[NATIVE-OWNERSHIP]]
## Kept constants (#999)

- `CoreConstant` lowers to a branch on whether the constant is built: the hit path reads the kept value; the miss path builds the initializer, keeps it, then joins.

Resolved Grill Log (#999): **Q:** Where is the build placed relative to the join? **A:** Only the miss path builds, so the initializer runs at most once per run and both paths join with the same value. _Rejected:_ building unconditionally before the branch.
