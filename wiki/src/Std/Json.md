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
## Governance and algorithm
The recursive reader advances an explicit scalar index, rejects trailing or malformed input as `Result`, and the encoder escapes strings deterministically.

String decoding is divided at the escape boundary. `readText` owns only the quoted-string loop:
it either finishes at a closing quote, appends an ordinary scalar, or delegates one backslash escape.
The escape reader returns both decoded text and the first unread source position, so the loop never
has to compensate for one-character and six-character escape forms with shared index mutation.

The admitted escape vocabulary is JSON's: quote, reverse solidus, solidus, backspace, form feed,
newline, carriage return, tab, and four-hex-digit Unicode escapes. An unrecognised escape is an
`Unexpected` error at the escaped character. A high UTF-16 surrogate must be followed by a Unicode
escape carrying a low surrogate; the pair is composed into one scalar. An isolated low surrogate,
an incomplete pair, or a value that cannot form a scalar is rejected at the position that made the
escape invalid. The public `Json`, `JsonError`, and function surface does not change.

Encoding applies the inverse escape table without a nested conditional ladder. It always escapes
quote, reverse solidus, backspace, form feed, newline, carriage return, and tab; every other control
below U+0020 uses `\u00XX`, and remaining scalars are written directly. Decoding rejects those
controls when they occur unescaped. This keeps `decode(encode(value))` stable for string values and
prevents the encoder from emitting text outside JSON's grammar.

## Evidence

- A focused executable fixture covers plain text; quote, slash, reverse-solidus, named and unnamed control, BMP,
  and surrogate-pair escapes; compact encode/decode round trips; invalid escapes; malformed hex;
  isolated surrogates; and unterminated strings.
- The standard-library program test runs that fixture through the ordinary compiler and evaluator,
  so private helpers are exercised through the exported `decode` and `encode` boundary.
- Formatter, checker, O0 evaluation, O2 evaluation, and the full compiler suite form the delivery gate.

## Grill Log
- **Q:** Why keep objects as ordered pairs? **A:** Encoding remains deterministic and preserves source order while lookup still has an explicit rule. _Rejected:_ host-map ordering.
- **Q:** Why not keep accepting every character after a backslash? **A:** That produces values from text JSON itself rejects and hides misspelled escapes. A typed parse error is safer than inventing data. _Rejected:_ permissive pass-through for unknown escapes.
- **Q:** Why compose surrogate pairs when Pudu strings contain Unicode scalars? **A:** JSON's `\u` notation carries UTF-16 code units, not necessarily complete scalars. Combining the pair at the boundary preserves Pudu's scalar invariant. _Rejected:_ admitting surrogate code points; rejecting every supplementary escaped scalar.
- **Q:** Why return the next source position from the escape helper? **A:** Escape forms consume different widths. Returning the cursor makes that fact part of the helper's result and removes compensating increments from the main loop. _Rejected:_ a mutable cursor shared between helpers; sentinel widths.
- **Q:** Should escape helpers be exported as a new standard-library abstraction? **A:** No. They exist to enforce `Std.Json`'s wire-format contract and would expose UTF-16 details to ordinary Pudu programs. _Rejected:_ public `decodeEscape`; a second internal-looking module with public implementation details.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
