---
type: module
path: "@root/src/Pudu/Eval/Json.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance, json]
aliases: [Eval Json]
---

# Eval Json

## Purpose, interface and invariants

`Pudu.Eval.Json` decodes JSON text into the values [[Std Json]] declares, so reading a document costs
native work rather than an interpreted step per character.

- `jsonDecode(source: Str) -> Option[Std.Json.Json]` answers the value a text holds, or `None`.
- `decodeDocument` is the pure decoder behind it.

`None` is not a verdict that the text is invalid. It is answered for every text this decoder cannot
read exactly as `Std.Json.decode` reads it, and `decode` then reads the text itself, so a refusal keeps
the error position and wording callers see. The decoder accepts: whitespace of space, tab, carriage
return, and newline; `true`, `false`, `null`; numbers `-?digits(.digits)?([eE][+-]?digits)?` whose
whole part has no leading zero and whose whole value's magnitude fits `Int`; strings without raw
control characters, with the escapes `\" \\ \/ \b \f \n \r \t` and `\u` hex escapes where a high
surrogate is followed by a low one; lists and objects nested fewer than 512 deep, with object entries
kept in order, duplicates included. Anything else is left to the library.

## Algorithm

One pass over the text's UTF-8 bytes. A string is read by searching for the next quote, backslash, or
control byte, and a run between them is decoded as one slice; every other token is a few bytes.
Lists and objects gather members in a sequence and build the `List` or `Object` variant once at the
closing bracket. Values are the evaluator's variant values under the names `Std.Json` declares, so a
decoded value is indistinguishable from one the library built.

## Grill Log

- **Q:** Index structural characters in a separate stage first? **A:** Not as a separate array.
  _Rationale:_ the value is built as it is read, and a byte search that skips string bodies is the part
  of structural indexing that matters here. _Accepted:_ one pass.
- **Q:** Report errors natively? **A:** No. _Rationale:_ positions and wording belong to the library's
  decoder; only invalid or unusual input pays for its slower read.
- **Q:** Accept `01` or `1.` as the library does? **A:** No. _Rationale:_ they are not JSON, and
  refusing them hands the library its own reading unchanged.

## Dependencies and consumers

- **Requires:** [[Eval Env]], [[Eval Value]].
- **Consumed by:** [[Eval Builtin]], [[Std Json]].

## Referenced by

[[src/_MOC]] · [[Std Json]]
