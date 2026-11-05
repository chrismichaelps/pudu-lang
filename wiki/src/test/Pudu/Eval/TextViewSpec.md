---
type: module
path: "@root/test/Pudu/Eval/TextViewSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Text View Model Tests]
---
# Text View Model Tests

Export testTextView and testTextByteBoundary. Compare byte slices, searches, scalar decoding and raw
byteAt with independent ByteString/UTF-8 reference models over mixed-width
text at every nearby offset. Include arbitrary mathematical offsets past the
host range. Primitive wrappers also prove E7001/E7003 and the original call
span for malformed dynamic arguments.

Resolved Grill Log: expected bytes come from an independent encoding model,
not another call to the helper under test. Test only already-bounded host
indices in the oracle. Preserve overlap and empty-needle cases.

## Referenced by

[[Eval TextView]] · [[Eval Test Coordinator]]
