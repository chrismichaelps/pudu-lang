---
type: handoff
status: ACTIVE
issue: 899
aliases: [Native Calls Delivery]
---

# Native Calls Delivery

Language Architect → Backend Engineer. This partition owns phase 0 of
[[Pudu Native]] after [[Native Mobile Targets Delivery]]: the single-start
entry guard (landed here) and calls from a host into exported Pudu functions
(designed here, not implemented). Backend Engineer → Forensic Guardian review
covers [[Backend Emit Entry]].

## Landed

[[Backend Emit Entry]] admits one `pudu_program_run` per process with a C11
atomic flag. Every later call returns `PUDU_PROGRAM_ALREADY_STARTED` before
touching runtime state. The cost is one test-and-set per start and nothing on
any call path inside the program.

## Design: calls into exported functions

| Concern | Decision |
| --- | --- |
| Which functions | Root-module `export fn` declarations whose parameters and result are crossing types: fixed-width integers, `Float32`, `Float64`, `Bool`, and `()` results. Others are refused with E6001 at the declaration when building a mobile target. |
| Reachability | Lowering takes the exported names as roots beside `main`, so an export that `main` never calls is still lowered and specialized. |
| C symbol | `pudu_export_<name>` with the C types [[Backend Emit Foreign ABI]] already assigns; conversions reuse `fromAbi` for arguments and `toAbi` for the result, inlined at the wrapper, so no lookup or boxing happens per call. |
| Header | `pudu_program.h` declares every export with its exact prototype. |
| Runtime state | An export requires a completed start or a running program on the calling thread; the runtime is prepared once by whichever runs first. |
| Threads | One thread owns the runtime: the first to enter it. A call from another thread, or a call while the runtime is already running a call from C, is a program failure with a located message, not undefined behavior. Concurrent calls need the shared-value thread model first. |
| Failures | A function whose result is `Result[T, E]` returns a status and writes `T` through an out parameter; typed failures never end the host. Runtime faults (arithmetic, bounds, memory) still end the process, as they do for the entry. |
| Performance | A call costs one frame allocation, exactly like a call inside the program. Leaf exports with scalar crossings are the first candidates for a direct C function without a frame; the frame path stays the reference until a measured comparison at `-O2` on device shows the gain. |

## Resolved Grill Log

- **Q:** Export every `export fn`? **A:** No. _Rationale:_ only crossing
  signatures have a defined C shape; widening the set waits on the same rules
  foreign calls use. _Rejected:_ boxing arbitrary values behind opaque handles
  now.
- **Q:** Look exports up by name at run time? **A:** No. _Rationale:_ a direct
  symbol per export keeps the call a plain C call, and the iOS linker can strip
  what the host never references. _Rejected:_ a dispatch table keyed by text.
- **Q:** Allow reentry from a foreign callback? **A:** Not in this partition.
  _Rationale:_ reentry needs the callback and thread-affinity rules of
  [[Foreign Callbacks and Thread Affinity]] to land in native emission first.

## Validation

`embedded native entry returns status, flushes, and runs once per process`
([[Native Frame Body Tests]]) compiles the embedded unit with a separate C
host under `-std=c11 -pedantic -Wall -Wextra -Werror`, calls the entry twice,
and requires the second call to answer `PUDU_PROGRAM_ALREADY_STARTED`.

## Exact next action

Add the exported names as lowering roots in `lowerProgram` (`Pudu.Compiler.Lower`)
and record each export's identity in the frame module, with its mirror page
and Grill Log first.

## Referenced by

[[handoffs/_MOC]] · [[Pudu Native]] · [[Backend Emit Entry]]
