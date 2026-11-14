---
type: handoff
status: ACTIVE
issue: 904
aliases: [Native Direct Calls Delivery]
---

# Native Direct Calls Delivery

Language Architect → Backend Engineer. This partition owns section 1 of [[ADR-0031-compiled-native-execution]]: direct calls for functions with bounded call depth. Backend Engineer → Forensic Guardian review covers [[Backend Frame Direct]], [[Backend Frame Bodies]] and [[Backend Frame Runtime]].

## Scope

- Eligible functions are called directly from heap-path bodies, from direct bodies and from exports.
- Unwinding, owned-slot release, blame and E7002 behave the same as on the heap path.
- Recursion, function values and oversized frames keep the heap path.
- A measured `-O2` comparison of heap call, direct call and hand-written C.

## Landed

Direct selection ([[Backend Frame Direct]]), direct bodies and inline calls ([[Backend Frame Bodies]]), stacked frames ([[Backend Frame Runtime]]), stack-frame entries and direct exports ([[Backend Frame Program]], [[Backend Emit Export]]). Focused direct, frame and export groups pass ([[Native Direct Call Tests]]).

## Measurement

| Build | 20,000,000 calls of `mix` (bench/CallBench.pudu) | Per call, loop included |
| --- | --- | --- |
| Heap frames (dev before this change) | 1,137–1,144 ms | about 57 ns |
| Direct calls, slots in frame storage | 516–521 ms | about 26 ns |
| Direct calls, unowned slots in C locals | 276–294 ms | about 14 ns |
| Hand-written C, same checked arithmetic (bench/CallBench.c) | 82 ms | about 4 ns |

Apple M-series laptop, macOS, cc -O2, five runs for the first and last rows and three for the others; checksums identical in every run. The remaining gap to hand-written C is the integer carrier: every `Int64` operation goes through the sign-magnitude `pudu_int` with a run-time kind, and every call passes arguments through the frame's argument cells.

## Exact next action

Open the PR for #904. Then give fixed-width integers a native carrier in direct bodies (an `int64_t` local with overflow-checked builtins), and pass direct-call arguments as C parameters.

## Referenced by

[[handoffs/_MOC]] · [[ADR-0031-compiled-native-execution]]
