---
type: module
path: "@root/src/Pudu/Compiler/Lower/Text.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Text]
---
# Compiler Lower Text

## Purpose and interface

Export lowerTextMethod, given the expression lowerer, the call span, the
receiver, the member name and the arguments. When the receiver lowers to Str
and the member is a native method with its checked argument types, answer a
`CoreTextMethod`; otherwise refuse the construct at the call.

| Method | Arguments | Result |
| --- | --- | --- |
| length, isEmpty, reverse, escapeHtml | none | Int, Bool, Str, Str |
| contains, startsWith, endsWith, indexOf | Str | Bool, Bool, Bool, Int |
| spanOf, spanNotOf | Str | Int |
| drop, take, repeat | Int | Str |
| slice | Int, Int | Str |
| replace | Str, Str | Str |

## Negative logic

No impl lookup: the evaluator answers built-in Str methods before any impl
(`callMemberSelecting`), so an impl method of the same name never runs on a
Str receiver. Methods outside the table refuse; nothing falls back.

## Grill Log

- **Q:** Why lower the receiver first when it runs last? **A:** Its type picks
  the method; lowering builds Core only, and Core records the evaluation
  order the emitter follows. _Rejected:_ guessing the receiver type from
  syntax.
- **Q:** Should a Never argument still build a method? **A:** No; like calls,
  the arguments run for their effects and the expression is Never.

## Arrays and options (#559)

Resolved Grill Log: `split`, `lines` and `chars` are runtime calls answering
arrays ([[Native Text Pieces]]). `toInt` and `toFloat` put the receiver in a
local, then `TextParsesInt`/`TextParsesFloat` choose between `Some` of
`TextIntOf`/`TextFloatOf` and `None`, built at the Option type the checker gave
the call ([[Native Text Number]]). No C code needs to know an Option's layout.
`toBytes` and `toDecimal` wait for Bytes and Decimal.

## toBytes (#565)

`Str.toBytes()` wraps the text's own storage as Bytes.

## Referenced by

[[Compiler Lower Body]] · [[Native Text Methods]] · [[src/_MOC]]

## Trim and case mapping (#517)

`trim`, `toUpper` and `toLower` take no arguments and answer Str; [[Native Text Case]] implements them.

## Char methods and charAt (#518)

`charAt(Int)` joins the Str table with a Char result. A Char receiver
answers `code` (Int, `CoreCharCode`) and `toText` (Str, `CoreDisplay`), which
is what `readCharMember` finds before any impl; other Char members refuse.
