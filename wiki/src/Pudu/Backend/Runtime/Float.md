---
type: module
path: "@root/src/Pudu/Backend/Runtime/Float.hs"
fidelity: Active
aliases: [Native Floating Runtime]
grammar: "[[grammar/haskell]]"
---
# Native Floating Runtime

## Purpose and interface

Export floatRuntimeParts :: [(Text,[Text])] and
floatRuntimeDependencies :: Text -> [Text]. Order [[Native Floating Values]],
[[Native Binary64 Formatter]] (including its natural kernel) then print_float.
Preserve the exact helper names and adapted notices. Compose value/format
prerequisites and add print_float -> float_format. No RuntimePart import cycle.

void pudu_print_float(uint64_t bits) formats into char buffer[32], appends newline
in the reserved byte, writes once with fwrite(buffer,1,count,stdout) and flushes
once. Ignore write/flush results in the same effect-only contract as existing
printers; callers cannot expose an invented successful Result. The shared
process policy governs SIGPIPE; do not reset handlers inside the printer.

No allocation, runtime file lookup, libc floating formatting or locale policy.
Raw formatting/printing needs only integer bit operations and must not select
host floating assertions or arithmetic. No source admission or representation
change; the current runtime revision remains 7 until the frame bridge.

## Resolved Grill Log

- **Q:** Print then append newline in a second write? **A:** Reserve its byte and write one whole line.
- **Q:** Abort on ignored print failure? **A:** Preserve continuation and the existing process policy.
- **Q:** Require IEEE host arithmetic just to print bits? **A:** No; select only the formatter closure.

## Dependencies and consumers

[[Native Floating Values]] · [[Native Binary64 Formatter]] · [[Backend Runtime]] · [[Native Runtime Dependencies]] · [[Native Floating Runtime Tests]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Floating Runtime Delivery]]
