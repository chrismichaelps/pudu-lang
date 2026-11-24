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
function, using typed heap-frame slots and jumps between local labels. A
program-counter switch admits the entry and suspended continuations.
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

## Algorithm and invariants

### Direct bodies

Every function still gets `pudu_body_<n>` for the function table. A direct function's code
is emitted once as `static pudu_cell pudu_run_<n>(pudu_frame *frame)` and
starts at its entry label. Its return yields
the retained result cell; its failure paths call the failure helper and then `abort()`. Its
table body only forwards to `pudu_run_<n>` and returns the result as a return step.

In any body, a call to a direct callee is emitted inline: the E7002 depth check at the call
site, `pudu_direct_<m>(frame->arguments)`, the destination's previous owned value released (or
the answer released when there is no destination), the depth restored, and the resume label
taken, without returning to the dispatcher. Prototypes of every `pudu_run_<n>` and
`pudu_direct_<n>` precede the bodies. Each of these prototypes carries an assembler label built from the Pudu name, the role (body, run or direct) and the index, such as `pudu_View_Markdown_parseWithTitle_body1854`, so profilers show the Pudu name while calls inside the generated C keep the indexed names.

Slots that own nothing are C locals named `pudu_s<n>` in a direct body, because nothing outside the body reads them: unwinding releases only owned slots. Only slots the body mentions are declared; a parameter local starts from its frame slot, any other starts zeroed. Owned slots stay in the frame so unwinding can release them.

## Negative Logic (Prohibited Paths)

- No call through a function value inside a direct body.

## Resolved Grill Log

- **Q:** Leave recursive C calls in expression code? **A:** No; calls return steps.
- **Q:** Put argument vectors on the C stack? **A:** No; frame-owned scratch holds them.
- **Q:** Claim #499 fixed before dispatch integration? **A:** No; this independently testable generator leaves the allocation boundary open.
- **Q:** Which edges need a program counter? **A:** Only a call that returns
  to the dispatcher writes a resume counter. Local branches and direct-call
  continuations jump within the body. Every emitted target must exist in the
  same function, and an invalid incoming counter still returns an invalid step.
- **Q:** Can one tag select among several arms? **A:** A variant switch
  evaluates its retained subject tag once and jumps to the selected arm.
  The default remains the match's next applicable arm or source diagnostic.
- **Q:** Rewrite slot text instead of threading a locals mode through value emission? **A:** Every slot reference the emitters produce has the one form `frame->slots[<n>]`, so a rewrite over the lines a direct body added is exact and keeps value emission single. _Rejected:_ a second copy of value emission.
- **Q:** Does a profiler label change the calls in the generated C? **A:** No. A label on the first declaration renames the symbol without touching any reference, so the indexed names stay in every call.

## Dependencies and consumers

[[Core Frame IR]] · [[Backend Frame Values]] · [[Backend Emit State]] · [[Native Execution Frames]] · [[Backend Frame Direct]]

## Grill Log

- **Q:** How is `FrameFailText` emitted? **A:** As `pudu_fail_text` with a site that keeps the code, help and place, and the message slot's text (#525).

## Calls through values (#555)

Resolved Grill Log: the step's callee is the closure's cell 0 and the closure
is argument 0. The function-number table goes into the emit state for closure
makers.

## Moves (#556)

Resolved Grill Log: `FrameMove` releases the destination's old value, stores
the source's and empties the source (an empty text for text).

## Computed help (#558)

A failure with computed help calls `pudu_fail_text_help` instead of
`pudu_fail_text`.

## Referenced by

[[src/_MOC]] · [[Native Frame Pressure Repair]]

## Wide frame bridge (#506)

Select wide_print_int for a 128-bit print slot through integerHelper; returns use the result type cell member and typed zero. Resolved Grill Log: calls copy complete saved cells, with unchanged suspension, ordering and cleanup contracts. [[Native Wide Frame Bridge]].

## Floating prints (#512)

`FramePrintSlot` on a float slot calls `pudu_print_float` and selects
`print_float`. Returns write the `floating` cell member.

## Text stores (#515)

A store into a text slot computes the new reference, releases the old one and
then assigns, so `s = s + t` reads `s` before letting it go. A text return
retains the slot it returns, because the frame releases its slots afterwards.
Printing a text slot calls `pudu_print_text`.

## Char prints (#518)

`FramePrintSlot` on a Char slot (the fused `print(display(c))`) calls
`pudu_print_char`.

## Owned stores and returns (#521)

A store into any owned slot (text or tuple) builds the new value, releases the
old one and assigns. Returns retain owned results. Printing a tuple slot shows,
prints and releases the text.

## Named callable dispatch (#568)

Resolved Grill Log: Mark FrameCallValue steps with closure_call=1, preserving closure-plus-arguments scratch cells and the original invocation site.

## Caller failures (#631)

FrameFailCaller writes `pudu_fail_text_caller(frame->call_site, code, help,
message)` and returns PUDU_INVALID, needing the fail_text_caller part.
Resolved Grill Log: the code and help are C string literals; the caller site
contributes only where the error points.

## Shared text stores and moves (#821)

Emit calls to the selected helpers from [[Native Text Runtime]] for both
FrameStore to text and FrameMove of text. Preserve the existing inline
typed sequences for other carriers.

Resolved Grill Log: selecting the text helpers per operation shortens
repeated display and stream output sequences. Evaluation order and the
release point remain the same.

Resolved Grill Log: a transferred argument is moved into the argument area and
its slot cleared; the call sets the transfer mask, in the call step on the heap
path and before the direct call. [[NATIVE-OWNERSHIP]]
