---
type: module
path: "@root/lib/Std/Fmt.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.4
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.7
tags: [module, stdlib, medium]
aliases: [Std Fmt]
---

# Std Fmt

## Purpose

Hold the decisions about how a value is shaped — width, fill, alignment, sign, grouping — as a value
that can be named, passed, and reused.

## Interface

25 exports: the `Align` and `Spec` types, `spec` and its builders (`width`, `filledWith`, `aligned`,
`leftAligned`, `rightAligned`, `centred`, `withSign`, `grouped`), readers (`widthOf`, `fillOf`,
`alignOf`), shaping (`text`, `int`, `zeroPadded`, `hex`, `octal`, `binary`, `radix`, `fixed`,
`list`), and `truncated` and `columns`.

### Governance

- **No format string, and nothing parsed at run time.** A spec is a value the checker sees, so a
  width that is not a number or an alignment that is not one of the three is a type error rather
  than a line that comes out wrong. This is the constraint [[architecture/STDLIB]] reserved the
  module under.
- A width is a **least** width. Content at least as wide is answered unchanged, because losing
  characters is worse than losing a column. `truncated` is how the other thing is asked for, by name.
- `fixed` takes a **`Decimal`**, never a `Float`. A figure shown to a fixed number of places is
  almost always money or a measurement, and a float cannot hold those exactly.
- Rounding is half away from zero — the rounding a reader does by hand — and never truncation, since
  a figure produced by cutting is wrong by up to a whole place and reads as exact.
- `zeroPadded` keeps the sign in front of its zeros. Filling with `'0'` through `filledWith` would
  answer `00-42`, which is not a number.
- Grouping counts **digits**, not the sign: `-1,234` groups three digits, not the two left after a
  minus was counted.
- The separator for grouping is the caller's. Which mark reads as a thousands separator depends on
  where the reader is, and the language has no opinion about that.
- Every builder answers a new spec and leaves the one it was given alone.

### Linkage

- **Requires:** [[Std Decimal]], [[Std List]], [[Std Text]].
- **Consumed by:** programs. Pairs with [[Std Out]], which settles how the result is written.

## Algorithm

`text` is the one shaping rule and every other function is stated through it: render the value to
text, then place it within the width. `columns` measures each column from the rows it was given,
since a caller cannot know a width until every row is in hand.

## Negative Logic (Prohibited Paths)

- No format-string interpretation, here or anywhere in `Std`.
- No truncation from a width; only from `truncated`, which says so in its name.
- No `Float` in `fixed`, which would make an exact-looking figure inexact.
- No sign counted as a digit when grouping, and none placed after padding.
- No writing: shaping answers text, and [[Std Out]] writes it. Keeping them apart is what lets each
  be checked by comparing values.

## Edge Cases

- A width of zero or less shapes nothing; content wider than the width is unchanged.
- A centred odd remainder goes right, so a column of centred values has a straight left edge.
- `truncated` never answers wider than asked, and a width too small for the marker answers the
  marker cut to that width.
- A base outside two to sixteen answers the number in ten rather than inventing digits.
- `columns` pads a short row with empty cells rather than refusing it.
- `fixed` asked for more places than the value carries pads with zeros, so a column lines up on its
  point.

## Depth

DEPTH 0.40 (MEDIUM). One placement rule, and renderings that all feed it.

## Grill Log

- **Q:** Why not a format string, when every reader knows one? **A:** Because it is a second
  language inside a literal that the compiler cannot check, which is the same reason
  [[architecture/STDLIB]] defers a regular-expression engine. _Rationale:_ a wrong spec becomes a
  type error rather than a line that comes out wrong at run time; the cost is keystrokes and the
  gain is that the checker reads it. _Rejected:_ an escape hatch taking a format string, which
  becomes the form everyone reaches for and makes the typed one decorative.
- **Q:** Why does a width not truncate? **A:** Because a column is a presentation choice and the
  characters are the data. _Rationale:_ silently dropping the end of an identifier to fit a column
  is a bug that looks like a layout; asking for it by name means the caller decided. _Rejected:_ a
  width that cuts, which is what most padding helpers do and what makes them unsafe to reuse.
- **Q:** Why does `fixed` refuse `Float`? **A:** Because the shape it produces claims an exactness a
  float does not have. _Rationale:_ two places is what money is written to, and a float that renders
  as `0.30` after three additions of `0.10` is the error [[Std Decimal]] exists to prevent —
  admitting the type here would reintroduce it at the last step. _Rejected:_ a `Float` overload, on
  the grounds that a caller with a float wants a `Decimal` and should be made to say so.
- **Q:** Why is this separate from [[Std Out]] rather than part of it? **A:** Because one decides
  what a value looks like and the other where it goes, and programs mix them freely — a shaped value
  is as likely to end up in a file, a message, or another string as on a stream. _Rationale:_ keeping
  them apart also keeps both checkable by comparing values. _Rejected:_ one module carrying both.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[Std Out]]
