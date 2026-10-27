---
type: module
path: "@root/src/Pudu/Backend/Runtime/Text/Case.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Text Case]
---
# Native Text Case

## Purpose and interface

Export textCaseRuntimeParts and textCaseRuntimeDependencies.

| Part | Provides |
| --- | --- |
| text_encode | UTF-8 encoding of one scalar |
| text_case_map | the row type, binary search and `pudu_text_case(text, rows, count)` |
| text_to_upper / text_to_lower | the upper/lower tables and `pudu_text_to_upper` / `pudu_text_to_lower` |
| text_trim | the whitespace set and `pudu_text_trim`, which returns a view |

The rows come from running `Data.Text.toUpper`/`toLower` on every scalar in
the compiler process; a scalar maps to itself unless it has a row. The row
width is the longest expansion either table needs, so a future text release
with longer expansions widens the rows instead of truncating them. The
whitespace set is `Data.Char.isSpace` over every scalar.

## Negative logic

No committed generated tables and no Unicode data files: the oracle is the
library the interpreter runs. No locale and no libc `towupper`. No context
rules, because text 2.1.4 has none for these functions.

## Grill Log

- **Q:** Why not generate from a Unicode release? **A:** The interpreter uses
  whatever Unicode version the linked text ships. That is text-2.1.4 from
  Hackage, while GHC's own boot package (what `ghc -e` sees) is 2.1.3, and the
  two differ by 56 case rows. A table taken from anywhere but the linked
  library would make native disagree with the interpreter in the same binary.
- **Q:** Does computing the table cost every build? **A:** Only builds whose
  program calls toUpper or toLower select those parts, and the tables are
  module constants computed once per process.
- **Q:** Can a per-scalar table model Text.toUpper? **A:** Yes for text 2.1:
  whole-string conversion equals the concatenation of per-scalar conversions
  [[Backend Text Case Tests]] checks this on the linked library with every
  scalar in one string plus final-sigma and dotted-I samples, and checks the
  native tables against Data.Text for every scalar.

## Referenced by

[[Native Text Methods]] · [[Compiler Lower Text]] · [[src/_MOC]]
