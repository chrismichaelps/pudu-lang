---
type: module
path: "@root/lib/Std/Json.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, json]
aliases: [Std Json]
---
# Std Json
## Purpose
Decode, encode, inspect, and immutably transform JSON values with positioned parse errors.
## Interface
Exports `Json`, `JsonError`, compact/pretty encoding, field/index/path lookup, typed projections, constructors, key updates, and error explanation.
`foldLines(file, seed, step)` folds a JSON Lines file one value to a line, skipping blank lines, and
answers `JsonLinesError`: `Unreadable(IoError)` or `Malformed(line, JsonError)` with the line counted
from one.
## Governance and algorithm
`decode` first asks the runtime's `jsonDecode` ([[Eval Json]]), which reads the text's bytes in one
pass and builds these same values. It answers only text it reads exactly as the reader below does and
leaves everything else, including every invalid text, to that reader, so a failure keeps its position
and wording. A 3.26 MB array of 20,000 objects decodes in 0.17 s this way against 17.5 s through the
reader below. `foldLines` runs over `Std.Io.foldLines`, so it holds one chunk of the file at a time:
199,415 values in 20 MB fold in 1.7 s at a 100 MB peak.

The recursive reader advances a private cursor — the unread remainder of the source and the scalar
position it begins at — rejects trailing or malformed input as `Result`, and the encoder escapes
strings deterministically. Text is UTF-8, so reaching a character by position walks every character
before it; the reader therefore examines only the front of the remainder and drops what it consumed.
Whitespace, digits, and plain string runs are skipped with `spanOf`/`spanNotOf`, and decoded string
pieces are joined once at the closing quote. Decoding is linear in the document: a 538-kilobyte
array of small objects decodes in about 2.4 s at -O2 against 9.1 s when every character was reached
by index, and a 200,000-character string in 3 ms against 1,970 ms.

Nesting is bounded. Each open list or object costs a reader recursion, and the evaluator bounds call
depth, so a value nested more than 512 levels deep answers `TooDeep` at the position of the opening
bracket or brace that exceeded the bound instead of stopping the program.

String decoding is divided at the escape boundary. `readText` owns only the quoted-string loop:
it either finishes at a closing quote, takes a run of ordinary scalars, or delegates one backslash
escape. The escape reader returns both decoded text and the cursor after the escape, so the loop never
has to compensate for one-character and six-character escape forms with shared index mutation.

The admitted escape vocabulary is JSON's: quote, reverse solidus, solidus, backspace, form feed,
newline, carriage return, tab, and four-hex-digit Unicode escapes. An unrecognised escape is an
`Unexpected` error at the escaped character. A high UTF-16 surrogate must be followed by a Unicode
escape carrying a low surrogate; the pair is composed into one scalar. An isolated low surrogate,
an incomplete pair, or a value that cannot form a scalar is rejected at the position that made the
escape invalid.

Encoding applies the inverse escape table without a nested conditional ladder. It always escapes
quote, reverse solidus, backspace, form feed, newline, carriage return, and tab; every other control
below U+0020 uses `\u00XX`, and remaining scalars are written directly. Decoding rejects those
controls when they occur unescaped. This keeps `decode(encode(value))` stable for string values and
prevents the encoder from emitting text outside JSON's grammar.

Encoding has no input-nesting refusal because it writes trusted `Json` values already held by the
program. Both forms are written by the runtime's `jsonEncode` ([[Eval Json]]) in one walk into UTF-8
bytes, with no evaluator frame per container and nothing interpreted per character, preserving the
established byte-for-byte formatting. Writing the 3.26 MB document takes 0.12 s where the former
`Writing`-stack encoder, which built each string one character at a time, took 12.2 s; 91 documents
encode to identical compact and pretty text either way, including every control character.

## Evidence

- A focused executable fixture covers plain text; quote, slash, reverse-solidus, named and unnamed control, BMP,
  and surrogate-pair escapes; compact encode/decode round trips; invalid escapes; malformed hex;
  isolated surrogates; unterminated strings; 512-level nesting accepted; list and object nesting past
  the bound refused as `TooDeep` at the exact opening position; and a long string with an escape
  between two 20,000-character runs.
- The standard-library program test runs that fixture through the ordinary compiler and evaluator,
  so private helpers are exercised through the exported `decode` and `encode` boundary.
- The same fixture reads the largest `Int`, refuses one past it where the number begins, folds a JSON
  Lines file with blank, whitespace-only, and CRLF lines, and names a malformed third line.
- 88 documents — every edge above plus numbers at and past `Int`'s bounds, leading zeros, `1.` and
  `1e`, trailing commas, 511- and 512-level nesting, a byte-order mark, and thirty generated nested
  documents — encode to identical text or explain identical errors through the native path and
  through the library reader alone.
- Formatter, checker, O0 evaluation, O2 evaluation, and the full compiler suite form the delivery gate.

## Grill Log
- **Q:** Why keep objects as ordered pairs? **A:** Encoding remains deterministic and preserves source order while lookup still has an explicit rule. _Rejected:_ host-map ordering.
- **Q:** Why not keep accepting every character after a backslash? **A:** That produces values from text JSON itself rejects and hides misspelled escapes. A typed parse error is safer than inventing data. _Rejected:_ permissive pass-through for unknown escapes.
- **Q:** Why compose surrogate pairs when Pudu strings contain Unicode scalars? **A:** JSON's `\u` notation carries UTF-16 code units, not necessarily complete scalars. Combining the pair at the boundary preserves Pudu's scalar invariant. _Rejected:_ admitting surrogate code points; rejecting every supplementary escaped scalar.
- **Q:** Why return the next source position from the escape helper? **A:** Escape forms consume different widths. Returning the cursor makes that fact part of the helper's result and removes compensating increments from the main loop. _Rejected:_ a mutable cursor shared between helpers; sentinel widths.
- **Q:** Should escape helpers be exported as a new standard-library abstraction? **A:** No. They exist to enforce `Std.Json`'s wire-format contract and would expose UTF-16 details to ordinary Pudu programs. _Rejected:_ public `decodeEscape`; a second internal-looking module with public implementation details.
- **Q:** Let nesting recurse until the evaluator's call limit? **A:** No. _Rationale:_ that limit
  stops the whole program, and deeply nested text is ordinary hostile input to a server. _Accepted:_ a
  512-level bound answered as `TooDeep`, far inside the evaluator's 4,096-frame limit. _Rejected:_ an
  unbounded reader; an iterative reader with an explicit stack, which is more code for no admitted
  document.
- **Q:** Keep indexing the source by scalar position? **A:** No. _Rationale:_ UTF-8 positions are
  reached by walking, which made decoding quadratic in document size. _Accepted:_ a private cursor
  over the unread remainder. _Rejected:_ a byte-offset string API added to the language for one reader.
- **Q:** Give program-built values the decoder's 512-level limit? **A:** No. _Rationale:_ the decoder
  rejects hostile external syntax before allocating an admitted value; the encoder operates on a
  value the program already owns, and its infallible signature promises to write it. _Accepted:_ an
  explicit work stack for both compact and pretty forms. _Rejected:_ silently truncating output;
  stopping the evaluator; changing encoding to an error solely because traversal was recursive.
- **Q:** Build indentation two spaces at a time in Pudu? **A:** No. _Rationale:_ repeated immutable
  concatenation copies every prefix and turns one indentation run quadratic in its width.
  _Accepted:_ the checked native `Str.repeat` operation. _Rejected:_ a local loop; adding another
  public builder abstraction when `Str.repeat` and `Std.Text.Builder` already cover the two needs.
- **Q:** Let the native decoder report errors? **A:** No. _Rationale:_ positions and wording would
  then have two sources that must agree forever. _Accepted:_ the native decoder answers only what it
  reads exactly as the library does, and every other text takes the library's reader. _Rejected:_ a
  native error vocabulary.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[Eval Json]]
