---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Time.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Time]
---
# Native Host Time

Export the family's runtime parts and their prerequisites.

The calendar arithmetic and an instant rendered with a pattern, as `Pudu.Eval.Clock` answers it. The pattern vocabulary is the platform's percent specifiers under the fixed English locale.

## Resolved Grill Log

- Use the C library's own formatter? No: its vocabulary, padding and locale differ from the interpreter's; the specifiers are rendered here from the calendar fields.
- Which calendar? The proleptic Gregorian one over 64-bit day counts, with the year unbounded by four digits.
- How does the formatter admit the full integer carrier? Divide its unsigned magnitude
  into days and milliseconds before applying the sign. Add the zone offset to the
  bounded remainder, then normalize to a nonnegative time of day and derive epoch seconds.
- Which zone names? `local` shifts by the machine's present offset; any other name shifts by nothing. The rendered zone is always UTC, as the shifted instant is.
- One modifier or several? One of `_`, `-`, `0`, `^`, `#`, then a width, then `E`, then the specifier.
- A percent with no specifier after it? It is written as itself and what followed is read as ordinary text.
- An unknown specifier? It renders nothing.
- Padding of a negative number? The sign first, then the padded digits.
- A width on a fraction? It truncates; elsewhere it widens only.

The calendar part asks for the clock header itself, so a program that renders
time and reaches no other clock still compiles.

## Referenced by

[[Native Host Runtime]] · [[Native Host Services]] · [[Native Host Time Reading]]
