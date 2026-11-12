---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/TimeParse.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Time Reading]
---
# Native Host Time Reading

Export the family's runtime parts and their prerequisites.

Text read as an instant with a pattern, as `Pudu.Eval.Clock` answers it, over the calendar of [[Native Host Time]].

## Resolved Grill Log

- Is whitespace significant? One space in the pattern reads one or more; the text may begin and end with spaces.
- Are letters case-sensitive? No, in literals and in names.
- How many digits does a number take? Up to its width, and every shorter length is tried when the rest does not fit.
- Missing fields? The date defaults to the first day of 1970, the time to midnight and the zone to no offset; a two-digit year below 69 is in the 2000s.
- Fields that disagree or name no day? The text does not fit the pattern.
- A text with more than one reading? Refused, as a text with none is: exactly one reading of the whole text must name an instant.
- Composite specifiers? Written out into their parts before reading; a padding modifier on one is dropped.
- A specifier that cannot be read, such as a newline or an unknown letter? The text does not fit.
- Which date field decides the day? The first of month, day of year or week number in the pattern; the others refine it.
- Seconds since 1970 in the text? They replace the date, time and zone and keep the fraction.
- A half millisecond? Rounded to the even millisecond.
- Leading spaces in the text? Skipped first; read as written only when no reading starts after them, as a pattern that itself begins with a space needs.
- How does a valid reading become an instant? Reduce the calendar by whole 400-year cycles, then
  add the displaced cycles using [[Backend Wide Operations]]. A cycle has a whole number of
  weeks, so the reduction also preserves weekday and week-date validation. Epoch seconds replace
  the entire date contribution after validation. The admitted field widths bound the wide
  intermediate. Round before testing the final magnitude.
- Where does the native result stop? The existing integer carrier holds either sign through a
  magnitude of `18446744073709551615`. Use the existing parse refusal beyond that magnitude
  without wrapping. The interpreter can return larger integers, and the native reader still
  refuses numeric fields whose magnitude exceeds fifteen decimal digits.
- The refusal? It names the pattern, which is the caller's, not the text.

- How is the refusal text built? The shared [[Native Text Runtime]] joins a fixed prefix and the borrowed pattern with checked size arithmetic. Construct the owned result before replacing the previous host message.

## Referenced by

[[Native Host Runtime]] · [[Native Host Services]]
