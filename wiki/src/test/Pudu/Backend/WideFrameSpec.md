---
type: module
path: "@root/test/Pudu/Backend/WideFrameSpec.hs"
fidelity: Active
aliases: [Native Wide Frame Tests]
grammar: "[[grammar/haskell]]"
---
# Native Wide Frame Tests

## Purpose and interface

Export wideFrameProperties :: [(String, IO Property)]. Construct valid typed
Core IR, lowerFrames then emitProgram, compile strict C11 and execute actual
heap frames. Reuse existing process/text/temp dependencies and PUDU_CC/cc.
Check stdout, stderr, status and normal/error frame cleanup.

## Algorithm and invariants

Both signed/unsigned 128-bit carriers cross literals, slots, calls, argument
snapshots and return payloads without losing high words or actual sign. Include
positive deferred 2^127, negative minimum, full unsigned maximum, narrow/unit
mixed cells, Bool-result comparisons and literal-only wide/unit entries.
Expected outputs/statuses use Integer math. Generated allocation/free counters
and an atexit check prove frame cleanup; real arithmetic refusal retains its
marker and code. Test the narrow-only ABI member/layout separately. Existing
source lowering still refuses these kinds until the following admission slice;
these Core-level tests must never be presented as public-source parity.

## Resolved Grill Log

- **Q:** Skip source checking and claim source admission? **A:** No; this is a deliberate private Core/frame bridge test only.
- **Q:** Compare only low words? **A:** Full decimal rendering and distinct signed/deferred boundaries expose high-word/sign loss.
- **Q:** Assume no leaks because the program exits? **A:** Count live frames on normal and failure exit.
- **Q:** Broaden old narrow frame layout? **A:** Prove the wide member is absent from narrow-only programs.

## Dependencies and consumers

[[Backend Frame Program]] · [[Backend Frame Values]] · [[Backend Frame Runtime]] · [[Compiler Frame Lowering]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Wide Frame Delivery]]

## Executed corpus and compiler hygiene (#506)

The 23 programs cover 14 signed/unsigned snapshot boundaries, two complete
operation programs, five literal/layout/comparison cases and two nested overflow
cleanup paths. Keep the separately generated C instrumentation warning-free
under Clang and GCC. Resolved Grill Log: allocation counters prove zero live
frames on normal/error exit; platform-unavailable LeakSanitizer is not evidence.
