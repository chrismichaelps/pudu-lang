---
type: module
path: "@root/src/Pudu/Core/Frame.hs"
fidelity: Active
aliases: [Core Frame IR]
grammar: "[[grammar/haskell]]"
---
# Core Frame IR

## Purpose and interface

Define nominal FrameLabel and FrameSlotId, typed/source-located FrameSlot,
FrameModule/Function/Block, flat FrameInstruction and FrameTerminator data.
FrameValue contains literals, reads, unary operations and eager scalar binary
operations only. FrameScalarOperator has a hidden constructor with a total
projection that excludes logical And/Or; those require branches. Instructions
store values or print literal/scalar values. Terminators jump, branch, call
with a continuation and optional destination, return, or report operator failure.
Calls cannot occur inside a right-hand side. Slot types remain canonical Core
metadata; this module performs no inference, IO, allocation or target encoding.
Function parameters reference their allocated slots. Every operation/control
site retains the original Span; synthetic jumps/implicit returns may have no
source site. FrameFault carries optional span and reason as data.

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

- **Q:** What do frames add for sums? **A:** `FrameConstruct` (variant index and payload), `FrameIsVariant`, `FramePayload` read only after the tag matched, `FrameRuntimeKind`, the `FrameFailText` terminator, and the module's layouts (#525).

## Closures (#555)

Resolved Grill Log: `FrameClosure` and `FrameCapture` values, the
`FrameCallValue` terminator (closure first, then arguments), and the module's
closure information.

## Variant dispatch

Resolved Grill Log: `FrameSwitchVariant` carries one retained subject slot,
distinct numeric variant tags with local targets, and a default target.
The edge selects the tag and leaves payload checks to its target block.

## Arrays and moves (#556)

Resolved Grill Log: `FrameArray`, `FrameArrayMethod`, `FrameIndex` and the
`FrameMove` instruction, which moves one slot's value into another and leaves
the source empty.

## Computed help (#558)

`FrameFailText` carries an optional slot of help text computed at run time.

## Integer conversion (#560)

`FrameIntegerFits` and `FrameIntegerConvert` carry the target kind and the
source slot.

## Maps and sets (#561)

`FrameKeyedMethod` and `FrameComparable` mirror the Core shapes.

## Char from a code (#562)

`FrameCharOfCode` mirrors `CoreCharOfCode`.

## Range values (#564)

`FrameRangeValue` and `FrameRangeMethod` mirror the Core shapes.

## Bytes (#565)

`FrameBytesMethod` mirrors `CoreBytesMethod`.

## Foreign calls (#850)

`FrameForeign` holds the declaration and the argument slots of a foreign call.

## Resolved Grill Log for #876 — Native callback lowering

FrameCallback retains the operation and its evaluated handler or token slot.
FrameForeign keeps callback positions separate from the Pudu operand list.

## Resolved Grill Log for #877 — Post-call settlement

FrameForeignSettle is an ordered, operand-free unit effect after loan writeback.

## Referenced by

[[src/_MOC]] · [[Program Compiler Module Map]] · [[Native Frame Pressure Repair]]

## Floating cells (#512)

`FrameFloatLiteral !FloatWidth !Word64` stores an encoding into a slot whose
type is `CoreFloatType`. Unary negation and the existing binary scalar
operators apply to floating slots; the slot type picks the helper.

Resolved Grill Log: floating values are scalars in the frame ABI like
integers and Bool, so no new instruction or terminator is needed.

## Text values (#515)

`FrameTextLiteral !Text`, `FrameDisplay !FrameSlot` and `FrameShow !FrameSlot`
produce text. Concatenation and comparison use `FrameBinary` on text slots.
Every text-producing value is a fresh reference; a store owns it.

## Text methods (#516)

`FrameTextMethod !CoreTextMethodName !FrameSlot ![FrameSlot]` computes a
method from already-evaluated slots. A method that can fail carries its
failure sites in the emitted call, like checked arithmetic.

## Char values (#518)

`FrameCharLiteral !Char` and `FrameCharCode !FrameSlot` are the only new
shapes. Comparisons, display, show and charAt reuse `FrameBinary`,
`FrameDisplay`, `FrameShow` and `FrameTextMethod` on Char slots.

## Tuples (#521)

`FrameTuple ![FrameSlot]` builds a tuple from evaluated slots and
`FrameTupleIndex !Int !FrameSlot` reads one member. Comparisons and
rendering reuse `FrameBinary`, `FrameShow` and `FrameDisplay`.

## Aggregates (#521)

`FrameTuple` and `FrameTupleIndex` are renamed `FrameAggregate` and
`FrameMember`: tuples and records share one boxed layout, members in
declaration order.

## Output Results (#566)

Resolved Grill Log: FrameOutputError mirrors CoreOutputError over one saved Str slot, preserving the ordered host effect and owned error text. See [[Native Output Results]].

## First-class output builtins (#569)

Resolved Grill Log: Rename FrameVariantName to FrameRuntimeKind, mirroring the dynamic sum/callable kind operation without changing operand order or ownership.

## Caller failures (#631)

`FrameFailCaller at code help message` ends a block with a refusal reported
at the frame's recorded caller site; `at` stays for faults during emission.
Resolved Grill Log: a separate terminator keeps FrameFailText's fixed-site
meaning intact. See [[Native Collection Callables]].

## Zero values (#638)

`FrameZero` stores the zero of the value's type. Resolved Grill Log: one
shape for every type, emitted from the slot type, rather than a literal per
carrier.

## Decimal (#802)

`FrameDecimalLiteral` and `FrameDecimalMethod`.

## Byte literals (#887)

`FrameBytesLiteral` is the frame value of `CoreBytesLiteral`: one value,
one slot, whatever the length.

## Module exports (#899)

`frameModuleExports` carries [[Pudu Core IR Module]]'s export keys unchanged
into the frame module, where [[Backend Emit Export]] reads them.

## Stored callable dispatch (#956)

Resolved Grill Log: A closure-target test reads its closure slot and names a linked body. Its result slot is Bool.

## Kept constants (#999)

- Value shapes `FrameConstantReady name`, `FrameConstantRead name` and `FrameConstantKeep name slot` read a kept constant: ready-check, read the kept value, or build and keep it into a slot.

Resolved Grill Log (#999): **Q:** Why separate ready, read and keep shapes? **A:** The hit path needs only the read, while the miss path builds and stores the value, so the lowering branches on readiness instead of rebuilding. _Rejected:_ one shape that always rebuilds.

Each kept cell holds its reference until the program ends. The first keep registers `pudu_constants_release` with `atexit` once, through `pudu_constants_arrange`, and that function releases every built cell by its type, so a kept value is never counted as memory the program lost and the allocation-balance tests stay exact. `emitConstants` records each cell's name and type, and `FrameConstantReady` carries the constant's type, so whichever read registers a cell first records the type its release needs. `constantRelease` in `Backend/Emit/Frame.hs` is rendered after the aggregate helpers because it calls their drop helpers. The full property suite passes 903 of 903.
## Drop slots (#1028)

`FrameFunction` gains `frameFunctionDrops`: the slots that own a value
needing drop, newest first, with the glue function that drops each when a
stop unwinds the frame.

Resolved Grill Log: newest first matches the scope order the interpreter
drops in, so both engines release the same values in the same order.
