---
type: handoff
status: ACTIVE
issue: 821
aliases: [Native Frame Slot Reuse Delivery]
---

# Native Frame Slot Reuse Delivery

Language Architect → Backend Engineer. Owns the physical allocation pass,
reference traversal and the emitter integration in [[Backend Frame Slots]],
[[Backend Frame Slot References]] and [[Backend Frame Program]]. The
partition follows [[Native Frame Slot Reuse]] and keeps Pudu semantics,
diagnostics and the native calling convention unchanged.

## Evidence

The structural slot test passed. Clang compiled 355 production translations
under strict C11, pedantic and warnings-as-errors flags. The signed Int8
pressure fixture produced the expected stdout byte for byte. GCC 15 also
compiled and ran the fixture under strict C11. The native diagnostic corpus
and 182 counted text allocation cases passed. Feed built as an arm64 iOS
simulator app with Apple's Boolean high-refresh opt-in in its Info.plist.

| Signed Int8 matrix | Before | After |
| --- | ---: | ---: |
| Frame slots | 6,394 | 4,561 |
| Owned slots | 4,131 | 2,756 |
| Generated C bytes, slot reuse alone | 1,429,513 | 1,414,651 |
| Generated C bytes, including text helpers | 1,429,513 | 1,227,359 |

The compacted translation repeated 2,295 text stores and 459 text moves.
The same fixture still matches its exact expected output after moving those
sequences into [[Native Text Runtime]], including under GCC 15. A smaller
loop and branch fixture that repeatedly replaces owned text matched the
interpreter under AddressSanitizer and UndefinedBehaviorSanitizer. The
signed Int8 fixture also matched under both sanitizers, and the strict C11
corpus and 182 counted ownership cases passed with the shared helpers.

## Exact next action

Run the complete iOS matrix on the integration head containing the C11
emitter changes. Capture physical 60 Hz and ProMotion frame timing
separately.

## Referenced by

[[handoffs/_MOC]] · [[Native Frame Slot Reuse]]
