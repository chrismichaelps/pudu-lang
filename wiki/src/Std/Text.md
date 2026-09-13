---
type: module
path: "@root/lib/Std/Text.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, text]
aliases: [Std Text]
---
# Std Text
## Purpose
Total, character-oriented helpers over `Str`: searching, trimming, padding, splitting, character
transforms and folds, comparison, and whole-number and count readers.
## Interface
Exports finding and stripping, `take`/`drop` and their end forms, `padLeft`/`padRight`/`center`,
splitting and words, `uncons`/`unsnoc`/`at`/`head`/`last`, character maps, filters, folds, scans, and
groups, `commonPrefix`, `breakOn`/`breakOnEnd`, `zipChars`, `unfold`, `compare`/`before`, title case,
line and word joining, and `wholeOf`/`countOf`.
## Governance and algorithm
Every function answers for every input rather than stopping the program: a position outside the text
is `None`, a slice clamps, and padding with an empty filler returns the text unchanged, since no
number of empty copies can reach a width.

Text is UTF-8, so reaching a character by position walks every character before it. Scans therefore
walk characters in order, or index the character array once, instead of calling `charAt` per
position; trailing runs are measured from the reversed text or the character array; and every
function that builds text gathers pieces and joins them once instead of appending to the text built
so far. Each is linear in the text: a 50,000-character trailing trim or predicate search is one pass.

Padding adds whole copies of the filler until the width is reached, so a longer filler may pass it;
`center` alternates copies starting on the left, giving the left the extra copy when the count is odd.
`breakOnEnd` finds the last occurrence as the first occurrence in the reversed text.
## Grill Log
- **Q:** Keep padding as a loop that appends until the width is reached? **A:** No. _Rationale:_ an
  empty filler never changes the length, so the loop never ended and the program hung. _Accepted:_ a
  computed whole-copy count, zero for empty filler. _Rejected:_ refusing empty filler with a new error
  type for a case with one honest answer.
- **Q:** Reach characters by position in scans? **A:** No. _Rationale:_ each positional read walks the
  UTF-8 prefix, making ordinary scans grow with the square of the text. _Accepted:_ in-order walks and
  one character array per call. _Rejected:_ a byte-offset string API added for these helpers alone.
- **Q:** Build results by appending characters to text? **A:** No. _Rationale:_ each append copies the
  text built so far. _Accepted:_ gathered pieces joined once.
## Referenced by
[[src/Std/_MOC]] · [[Std Text Builder]] · [[Std Text Parse]] · [[architecture/STDLIB]]
