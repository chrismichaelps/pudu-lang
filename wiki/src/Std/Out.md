---
type: module
path: "@root/lib/Std/Out.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.4
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.7
tags: [module, stdlib, medium]
aliases: [Std Out]
---

# Std Out

## Purpose

Hold the decisions about how output is written — separator, ending, prefix, stream — as a value that
can be named, passed, and reused.

## Interface

22 exports: the `Stream` and `Printer` types, construction (`stdout`, `stderr`, `bare`), the builders
(`toStream`, `separatedBy`, `endingWith`, `prefixedWith`, `indentedBy`), the readers (`streamOf`,
`separatorOf`, `endingOf`, `prefixOf`), the pure `rendered`, and the writing side (`write`, `text`,
`blank`, `value`, `values`, `lines`, `showing`).

### Governance

- **Rendering is separate from writing.** `rendered` answers exactly the text a write produces, so
  every configuration is checked by comparing values rather than by capturing output. Every writing
  function is stated in terms of it.
- A printer is a **value**. The decisions are made once and handed to whatever writes, so a function
  that reports something takes the printer to report through rather than settling the shape itself.
- The **ending is part of the text**, not something the stream adds. That is what makes an empty
  ending really leave the line open, which a prompt needs.
- A **prefix applies to every line**, including the lines inside a piece that already spans several.
  A prefix that decorated only the first line would indent a table by moving its top row.
- `indentedBy` **adds** to the prefix rather than replacing it, so indenting an indented printer
  nests. A count of zero or less adds nothing rather than removing what is there.
- The defaults are the familiar ones — a space between pieces, a newline at the end — so the common
  call needs no configuration.
- No partial functions, and every write answers `Result`.

### Linkage

- **Requires:** [[Std List]], [[Std Text]], and the `printPart` and `printErrorPart` prelude effects.
- **Consumed by:** programs. [[Std Fmt]] is intended to sit on top of this.

## Algorithm

`rendered` joins the pieces with the separator, applies the prefix to every line of the result, and
appends the ending. `write` hands that text to the stream's part-writer, which does not end the line
of its own accord.

## Negative Logic (Prohibited Paths)

- No format-string interpretation, here or anywhere; [[architecture/STDLIB]] settles that typed
  formatting is [[Std Fmt]]'s and carries no run-time parsing.
- No line ending supplied by the stream, which would make an empty ending a lie.
- No prefix on the ending, which ends a line rather than being part of one.
- No writing from `rendered`, which is what makes it usable in a test.

## Edge Cases

- No pieces renders the ending alone: a prefix decorates a line's content and there is none.
- No pieces and no ending renders nothing at all, and writes nothing.
- An empty piece is still a piece, so the separators around it remain.
- A separator containing a newline makes more lines, and the prefix applies to all of them.
- A negative indent adds nothing rather than removing existing prefix.
- Every builder answers a new printer and leaves the one it was given alone.

## Depth

DEPTH 0.40 (MEDIUM). One rendering rule, and a set of builders that only change what it reads.

## Grill Log

- **Q:** Why a printer value rather than arguments at the call site, as `print(x, sep, end)`? **A:**
  Because Pudu has no default, keyword, or variadic arguments, so every call would carry every
  decision positionally, and the decisions could not be named or passed. _Rationale:_ making them a
  value is what lets a reporting function take "where to report" as a parameter. _Rejected:_ a
  family of `printWith`-style functions, one per combination.
- **Q:** Why does `write` take an array of text rather than the values themselves? **A:** Because a
  line is often built from values of different types, and Pudu has no variadic call and no
  existential to hold them in one array. _Rationale:_ rendering each where its type is known and
  writing the pieces together is the honest spelling; `showing` covers the case where they share a
  type. _Rejected:_ a fixed set of arities, which caps how many pieces a line may have.
- **Q:** Why does `rendered` exist at all, when `write` could format inline? **A:** Because output is
  the one thing a test cannot easily look at. _Rationale:_ with rendering separate, the whole of this
  module's behaviour is checked without performing IO, and the fixture is a list of value
  comparisons. _Rejected:_ testing by capturing standard output, which cannot run in-process
  alongside the rest of the suite.
- **Q:** Should the prefix apply to the ending too? **A:** No. _Rationale:_ the ending closes a line
  rather than being content within one, and prefixing it would put the indent after the last visible
  character. _Rejected:_ treating the whole rendered string uniformly, which is simpler to implement
  and wrong to read.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[Std Io]]
