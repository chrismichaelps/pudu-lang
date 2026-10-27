---
type: module
path: "@root/src/Pudu/Backend/Emit/Frame/Body.hs"
fidelity: Active
aliases: [Backend Frame Bodies]
---
# Backend Frame Bodies

## Purpose and interface

Export emitFrameBodies :: EmitState -> FrameModule -> Either FrameFault
(EmitState, Set Text). Generate constant-arity C step functions, one per source
function, using typed heap-frame slots and a program-counter switch in a loop.
Numeric function identities follow module order. A call snapshots argument cells
into frame-owned scratch storage, saves the resume counter and returns a call
step with callee, count, destination and original call site. No generated user
body calls another body. Return steps copy their payload; unit returns carry no
source result and bare value returns preserve the existing ABI zero.

## Runtime contract and failures

The pending dispatcher provides pudu_cell (integer/scalar union), pudu_frame
(pc, slots, arguments) and pudu_step with kind, function, argument_count,
has_destination, destination, result and call_site. Step kinds are PUDU_CALL,
PUDU_RETURN and PUDU_INVALID. pc/slot/function fields use size_t. Body code
does not allocate frames or choose heap-failure policy. Invalid pc returns an
internal-invalid step, never a source diagnostic or interpreted fallback.
Select runtime roots from emitted instructions and terminators only. Print
uses existing byte lengths and shared helpers. All fault cases return data.

## Resolved Grill Log

- **Q:** Leave recursive C calls in expression code? **A:** No; calls return steps.
- **Q:** Put argument vectors on the C stack? **A:** No; frame-owned scratch holds them.
- **Q:** Claim #499 fixed before dispatch integration? **A:** No; this independently testable generator leaves the allocation boundary open.

## Dependencies and consumers

[[Core Frame IR]] · [[Backend Frame Values]] · [[Backend Emit State]] · [[Native Execution Frames]]

## Referenced by

[[src/_MOC]] · [[Native Frame Pressure Repair]]

## Wide frame bridge (#506)

Select wide_print_int for a 128-bit print slot through integerHelper; returns use the result type cell member and typed zero. Resolved Grill Log: calls copy complete saved cells, with unchanged suspension, ordering and cleanup contracts. [[Native Wide Frame Bridge]].
