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

- **Q:** Why lower the receiver first? **A:** Its type picks
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

## Option result layouts

Each numeric parser knows its result carrier. Use it to form the Option layout when the call does not carry that layout in its span facts.

## Referenced by

[[Compiler Lower Body]] · [[Native Text Methods]] · [[src/_MOC]]

## Trim and case mapping (#517)

`trim`, `toUpper` and `toLower` take no arguments and answer Str; [[Native Text Case]] implements them.

## Char methods and charAt (#518)

`charAt(Int)` joins the Str table with a Char result. A Char receiver
answers `code` (Int, `CoreCharCode`) and `toText` (Str, `CoreDisplay`), which
is what `readCharMember` finds before any impl; other Char members refuse.

## Decimal (#802)

`toDecimal()` lowers through [[Compiler Lower Decimal]].

## Native byte views (#827)

Export lowerTextPrimitive and textCallable in addition to lowerTextMethod. Consume the six exact checked builtin signatures; hold operands once left-to-right and stop on Never before later arguments. Build ordinary Option/tuple values with guarded byte/scalar reads. Search once into an Int local, branch on nonnegative result, then construct Some or None. Direct calls require the solved result; callable registration supplies its validated result explicitly. See [[Native Text Views]].

## Selected receiver layouts (#956)

Resolved Grill Log: Select the held receiver before emitting a text or character operation. A missing member fails at the callee before argument effects.

## Selected invocation arguments (#956)

Resolved Grill Log: Use the selected argument slots after all arguments run. An incompatible argument takes the string method’s invocation diagnostic.

## Selected text-view operands

Text-view primitives retain each operand before choosing the compatible
held layout, using the same argument messages from direct and stored
invocations. A stored method reports wrong arguments at its caller.

Resolved Grill Log: a selected incompatible text alternative reports
the primitive's type diagnostic after later operand effects. Declared
nominal methods keep lookup priority over the general renderer.

## Integer limits

A selected integer count feeds the scalar position operations through
their existing clamping rules. Repeat checks positive counts beyond
the runtime limit before narrowing and keeps the empty-text case.
Byte-addressed reads yield None for out-of-range held positions.

Resolved Grill Log: negative counts reach the same refusal as ordinary
Int counts. A view never treats an out-of-range bound as an exact
position, even when the clamped position is a valid boundary.

## Held collection member selection

Resolved Grill Log: Select the held receiver before delegating collection and nominal members. A missing member evaluates the receiver and stops before argument expressions.

## Held declared method receivers

Resolved Grill Log: A receiver already selected by declared-method dispatch follows the same member selection and missing-member diagnostic as a selected builtin receiver.

Resolved Grill Log: evaluate the receiver through [[Compiler Lower Place]]
before selecting its builtin family. Carry its optional place into
nominal fallback. Builtins use the retained value without writeback.

Resolved Grill Log: builtin lookup uses the unqualified member while the missing-member diagnostic reports the written name.
