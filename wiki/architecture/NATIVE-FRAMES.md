---
type: architecture
tags: [architecture, native, frames, control-flow]
aliases: [Native Execution Frames]
---
# Native Execution Frames

## Status and failure evidence

Local #499 implementation now includes Core-to-frame lowering, generated step
bodies, checked heap allocation, scalar frame cleanup and CLI integration.
The shared executable host-memory contract is defined below. Focused native
function failures, allocator lifetime/injection and host-exception tests passed
before the current clean full validation run. Independent architecture,
implementation and wiki review remain required before promotion. All 19 clean
repository gates and 669 test groups pass. The separate production native run
under AddressSanitizer/UBSan passes 20 groups against the tree evaluator.
Reported CLI HeapOverflow is verified in both engine modes with -M32m. Full
language coverage is still incomplete; these are local macOS results.

[[Compiler Frame Lowering]] now produces [[Core Frame IR]] with typed slots,
closed basic blocks and explicit call destinations/continuations. Seven focused
[[Native Frame Lowering Tests]] groups pass under optimized GHC 9.14.1 -Werror:
snapshots, logical guards, abrupt effects, nested calls, loop-target scope,
malformed-input faults and checked native-corpus graph closure. These fixed
checks cover pure transformation; runtime safety requires the separate engine
and observable execution tests.

[[Backend Frame Values]] and [[Backend Frame Bodies]] now generate separate,
constant-arity C step functions with frame-owned argument scratch, typed slot
access and return-by-step suspension. The CLI now lowers through this generator
and [[Backend Frame Program]]. Ten focused frame groups passed before runtime
integration; [[Native Frame Body Tests]]
compile 194 actual corpus translations with strict C11 warnings as errors.

A local test-only dispatcher with static storage for 4,097 frames executes the
wide-pressure reproduction using these actual generated bodies (973 slots,
97 call arguments). AddressSanitizer and UBSan report no issue; status, stdout
and E7002 stderr match tree and compiled CLI execution byte for byte on the
unchanged host stack. /tmp/pudu-499-frame-pressure-proof.json records evidence.
This static arena is a test fixture, not the production allocation strategy.
The production allocator, panic cleanup and CLI integration were subsequently
implemented. The unchanged function-failure corpus, including this pressure
case, passes through the production path. Complete clean validation now passes.

The original exact-integer ABI preserved deferred values but a checked program
with 96 integer parameters live across recursion exited natively with SIGSEGV.
Both evaluators produce E7002 at the recursive call. The local stack limit is
about 8 MiB and was not changed. [[Native Frame Pressure Repair]] records the
probe and permanent failing regression. Passing the earlier 656 groups did not
prove this case. Do not lower the language bound, enlarge the host stack as the
final fix, replace accepted calls with E6001, or interpret source as a fallback.

## Execution model

Lower structured Core to basic blocks whose calls suspend their caller. A
runtime dispatcher owns explicit frames and logical depth; generated user
bodies return a call/return step rather than recursively calling other user
bodies. The generated C call graph must have bounded depth independent of Pudu
recursion, argument count and live local count. Merely moving a few locals to
heap while retaining source-dependent C call frames is insufficient.

Each frame stores its function identity, resume block, typed locals and
expression temporaries. Keep arguments in frame-owned storage. A constructor
receives a pointer/count to an argument vector; do not reproduce arbitrarily
wide source signatures as C argument lists. Every value is evaluated and
snapshotted before the call step, so allocation/depth logic cannot precede an
argument's observable effects or abrupt transfer.

A call step names its original Pudu span, callee identity, typed argument
storage, destination slot (absent for unit) and resume block. A return step
snapshots a value before releasing the callee frame. The dispatcher writes that
value to the caller's live typed destination, releases the callee exactly once,
restores logical depth and resumes the saved block. Entry results retain their
existing reportResult semantics; their private carrier is not a public layout.

## Logical depth

The entry runs at depth 1. A source call evaluates all arguments first, checks
`depth > callDepthLimit` before incrementing, and only then enters the callee.
This permits depth limit + 1 and refuses the following call, as the evaluator
does. Preserve the exact shared E7002 code/message/help and call span.

A dispatcher may use a bounded pointer stack sized for limit + 1 active frames,
with checked size/index arithmetic. The pointer stack and payload storage must
not reside in source-dependent C automatic arrays. Depth counters and frame
ownership must agree on every normal return and failure; do not keep two
independently changing notions of depth.

## Core-to-frame control contract

- Give basic blocks nominal labels and locals/temporaries nominal slots with
  canonical Core types. Function identities and allocation order are deterministic.
- Pure right-hand sides cannot contain a call or structured control expression.
  Calls, branches, jumps, returns and operator failures terminate blocks.
  A logical And/Or cannot masquerade as an eager scalar binary operation.
- Reading a mutable local creates an expression snapshot before the next eager
  operand or argument starts. Copying values only when filling the final call
  vector would read a later mutation and change behavior.
- Logical operators branch around the entire right subtree and join through a
  typed Bool destination. A Never path has no payload or fabricated assignment.
- Blocks preserve statement order. Branch/loop value slots retain only values
  on reachable normal paths. Explicit returns bypass the enclosing result slot.
- Continue jumps to condition setup, break assigns its value after operand
  completion and then jumps out. Use resolved CoreLoopId destinations, including
  transfers in a while condition that target an outer loop. A transfer inside a
  break operand can prevent the enclosing break from executing.
- A call appearing inside an expression receives a resume block after its
  already-evaluated left operands. Preserve these temporaries in the caller
  frame, including nested calls in loop conditions and return/break operands.
- Operator-failure operands finish in order before E7001. An earlier error or
  transfer wins. Preserve operation spans and shared vocabulary without rendering
  diagnostics during control lowering.
- Runtime selection follows emitted reachable frame instructions and call
  continuations. It must not emit unused helpers for source/Core subtrees that
  become unreachable after an abrupt transfer.

## Runtime ownership and C boundary

A frame payload has stable storage until its call completes. Slot addressing,
argument/result unions and concrete frame casts must obey C11 alignment, aliasing
and lifetime rules. Select union members from checked canonical slot types;
source input cannot choose a mismatched runtime tag. Avoid zero-length arrays,
unbounded C signatures and automatic arrays proportional to source locals.

Normal returns free each frame exactly once after result transfer. Panics must
unwind frame storage before the process ends; future owned values require
explicit initialized/moved/drop state rather than freeing raw storage blindly.
Scalar frame storage does not justify claiming resource/drop coverage now.

The executable host-failure boundary now uses [[Host Failure Vocabulary]]:
`pudu: memory allocation failed`, one newline on stderr and status 1. This is
not a Pudu diagnostic, recoverable value or source-location claim.
[[CLI Memory Failure]] catches only catchable HeapOverflow around executable main; evaluator
libraries retain their host exception APIs. Native checked-size overflow and
reported calloc failure use the same text/status after unwinding scalar frames.
No cancellation/interrupt is reclassified. OS kills and unreportable RTS fatal
conditions cannot run a language handler and are not claimed as recoverable.
Controlled injection and real bounded-heap tests must validate this boundary;
its implementation and independent review are not implied by the design.

[[Backend Frame Runtime]] uses linked heap frames and a single active-top/depth
pair for the current scalar execution. A flexible-array allocation contains
slots and maximum call-argument scratch. Count additions and byte arithmetic
are checked before calloc; the existing top remains available if allocation
fails. The runtime installs its cleanup hook before entry allocation. Normal
returns transfer the copied result, unlink/free exactly one frame and decrement;
source panics and memory failures unwind every active frame before exiting.
This does not admit reentrant foreign calls or concurrency without per-execution
context ownership, nor owned-value drops without initialization/move state.

## Validation obligations

The permanent pressure reproduction must produce interpreter-identical E7002
with ordinary and exact integer values. Add large live-local sets, mutual
recursion, near-limit calls, nested calls and argument effects, short circuit,
Never transfers, unit/Bool/integer results, loop/branch continuations and source
provenance. Check normal frame reclamation and panic cleanup separately.

Pure control-lowering checks must pin snapshots, destination identities,
continuations and source spans. End-to-end tests compare actual output/status
with tree and compiled execution. Keep independent numerical expectations and
the exact-integer tests. Strict C11 warnings, sanitizer checks, complete gates,
supported-platform execution and independent review remain required. A passing
subset cannot close #499 or the full 100% emission goal.

## Resolved control-design Grill Log

- **Q:** Is the language's depth counter enough? **A:** No; large C frames can exhaust the host stack before the counter refuses a call.
- **Q:** Can argument vectors be automatic arrays? **A:** That retains source-dependent C stack pressure. Store them with the explicit frame.
- **Q:** Can a caller be freed before transferring its child's result? **A:** No; the result destination must remain live until the child returns and the caller resumes.
- **Q:** Rebuild semantics in the frame pass? **A:** No; consume checked, span-carrying Core identities and preserve existing operation policies.
- **Q:** Does this resolve allocation failure already? **A:** No; that runtime boundary remains explicit and must be settled before allocator implementation.

## Dependencies and consumers

[[Pudu Core]] · [[Exact Native Integer Carriers]] · [[Backend Emit]] ·
[[Backend Runtime]] · [[Diagnostic Evaluation]] · [[Native Emission Coverage]] ·
[[Backend Frame Values]] · [[Backend Frame Bodies]] · [[Native Frame Body Tests]]

## Referenced by

[[architecture/_MOC]] · [[Native Frame Pressure Repair]] · [[Native C11 Backend Delivery]]
