---
type: module
path: "@root/src/Pudu/Eval/Xml.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance, xml]
aliases: [Eval Xml]
---

# Eval Xml

## Purpose, interface and invariants

`Pudu.Eval.Xml` reads XML documents into the values [[Std Xml]] declares, so reading a document costs
native work rather than an interpreted step per character.

- `xmlDecode(source: Str) -> Option[Std.Xml.Tag]` answers a document's root element, or `None`.
- `decodeDocument` is the pure reader behind it, and `unescape` its entity decoding.

`None` is not a verdict that a document is malformed. It is answered for every document this reader
does not read exactly as `Std.Xml.decode` reads it, and `decode` then reads the document itself, so a
refusal keeps its error. The reading is the library's: declarations, instructions, and comments are
skipped before the root and a document type declaration is refused; a name ends at whitespace or any of
`< > / = " ' ? !`; attribute values are quoted with either quote; inside an element, a closing tag is
matched first, then comments, CDATA kept as written, and instructions, then nested elements to 512
levels; text that is only whitespace, by the same test `trim` uses, is dropped. The five entities and
numeric references are decoded when their `;` is among the next twelve characters; an unknown entity is
kept, and a reference naming no scalar value is dropped. Nothing after the root element is read.

## Algorithm

Every structural character is ASCII, so the reader walks the document's UTF-8 bytes: whitespace and
names are skipped byte by byte, text and attribute values are found by searching for their end, and
markers such as `-->` by substring search from the same position the library searches from. Each name,
value, and run of text is decoded once. Elements are the evaluator's `Tag` record with its fields in
declaration order, and children are `Element` and `Content` variants, so a value this reader builds is
indistinguishable from one the library built.

## Grill Log

- **Q:** Stream elements instead of building the tree? **A:** Not in this reader. _Rationale:_ it
  answers `decode`'s contract, a whole `Tag`; a pull reader over a file is a separate interface.
- **Q:** Report errors natively? **A:** No. _Rationale:_ positions and wording belong to the library's
  reader; only documents it refuses, or reads differently, pay for its slower read.

## Dependencies and consumers

- **Requires:** [[Eval Env]], [[Eval Value]].
- **Consumed by:** [[Eval Builtin]], [[Std Xml]].

## Referenced by

[[src/_MOC]] · [[Std Xml]]
