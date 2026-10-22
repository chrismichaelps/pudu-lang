---
type: module
path: "@root/test/Pudu/Backend/ReferencePrograms.hs"
fidelity: Planned
grammar: "[[grammar/haskell]]"
aliases: [Backend Shared Reference Programs]
---
# Backend Shared Reference Programs

Planned exports: referenceSuccessPrograms (label, source, expected stdout) and
referenceRefusalPrograms (label, source). Own a bounded ordinary-source corpus
with independent expected answers for [[Native Shared References]].

Resolved Grill Log: cover scalar/text/tuple/record/sum borrows, parameter and
result forwarding, field/index/payload reads, nested calls, exactly-once operand
effects, Never transfers and runtime failure provenance. Mutable loans and
print carriers belong in native lowering-refusal tests, not execution tests
that could pass merely because the interpreter also refused compilation.

[[Backend Module Programs]] will include the source programs in its existing
whole-program native harness. [[Backend Text Leak Tests]] will include the
successes in counted cleanup. This requires neither a new Main coordinator nor
more execution machinery in the already oversized NativeSpec. The actual
runner-consumed lists and named property output must be checked.

## Referenced by

[[Native Shared References]] · [[Backend Module Programs]] · [[Backend Text Leak Tests]]
