---
type: module
path: "@root/test/Pudu/Backend/TextMethodPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Text Method Programs]
---
# Backend Text Method Programs

## Purpose and interface

Export textMethodSuccessPrograms :: [(String, Text, Text)] and
textMethodRefusalPrograms :: [(String, Text)], run by [[Backend Native Tests]]
and, for successes, by [[Backend Text Leak Tests]].

## Coverage

Every native method on empty, ASCII, two-byte and four-byte text: empty and
missing needles, overlapping matches (`"aaa".indexOf("aa")`,
`"aaaa".replace("aa", "b")`), empty alphabets, counts of zero, past the end
and `maxBound :: Int`, slice bounds that are negative, reversed or past the
end, HTML escapes of all five marks. Views that outlive their source and are
returned from calls. Effect order: arguments before the receiver, a Never
argument that stops before the receiver runs.

Refusals: negative drop, take and repeat (including a negative repeat of
empty text, which still refuses), the repeat size limit, and a refusal whose
operands print first.

## Grill Log

- **Q:** Where do the answers come from? **A:** They are written out by hand
  rather than computed with Data.Text, so a shared library mistake cannot
  make both sides agree.

## Referenced by

[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Native Text Methods]] · [[src/_MOC]]
