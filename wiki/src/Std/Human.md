---
type: module
path: "@root/lib/Std/Human.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, text, configuration]
aliases: [Std Human]
---

# Std Human

## Purpose and interface

Quantities as people write and read them: byte sizes and durations in configuration, and sizes,
ordinals, counts, and relative times in messages.

- `type HumanError = Empty | NotANumber(Str) | UnknownUnit(Str) | NotWhole(Str) | TooLarge(Str)`;
  `explain(problem) -> Str`.
- `parseBytes(text) -> Result[Int, HumanError]`; `bytes(amount) -> Str` (powers of 1024:
  `1.5 KiB`); `bytesDecimal(amount) -> Str` (powers of 1000: `1.5 kB`).
- `parseDuration(text) -> Result[Time.Duration, HumanError]`; `duration(value) -> Str`
  (`1w1d1h1m1s1ms`, exact).
- `ordinal(value) -> Str`, `plural(amount, singular, many) -> Str`,
  `relative(moment, reference) -> Str`.

## Semantics

- A number is whole digits with an optional point and at most nine fraction digits, held as a
  numerator over a power of ten; every multiply and add is checked against `Int` and reports
  `TooLarge` instead of stopping the program.
- Byte units are case-insensitive: `b`; `k`/`kb` … `p`/`pb` in thousands; `ki`/`kib` … `pi`/`pib`
  in powers of 1024. A fraction is admitted only when it comes to whole bytes (`NotWhole` otherwise).
- `bytes` and `bytesDecimal` show one decimal place rounded half up (in 128-bit arithmetic), drop a
  `.0`, and move to the next unit when rounding reaches the base, so the answer is never `1024 KiB`.
  The most negative `Int` is written as its neighbour, which one decimal place cannot distinguish.
- Duration units are `ms`, `s`, `m` (minutes), `h`, `d` (24 h), `w` (7 d); pairs may be separated
  and spaced, one leading sign is admitted, and each pair must come to whole milliseconds. What
  `Time.describe` writes reads back. `duration` writes every non-zero unit so it round-trips.
- `ordinal` handles 11–13 and negatives. `plural` takes the plural rather than guessing it.
- `relative` answers `just now` within ten seconds, `yesterday`/`tomorrow` for one day, and
  otherwise the largest whole unit (seconds, minutes, hours, days, weeks, 30-day months, 365-day
  years), truncated.

## Grill Log

- **Q:** Treat `k`/`KB` as 1024? **A:** No. _Rationale:_ the two families differ by seven percent at
  a gigabyte; the binary family is spelled with an `i`. _Rejected:_ context-dependent units.
- **Q:** Round fractional bytes or milliseconds? **A:** Refuse. _Rationale:_ a configured limit
  that silently moves is a limit nobody set. _Rejected:_ truncation.
- **Q:** Round `relative`? **A:** Truncate. _Rationale:_ something 59 minutes old announced as an hour
  old overstates; truncation never does.
- **Q:** A month unit for durations? **A:** No. _Rationale:_ a month has no fixed length; `m` is
  minutes, which is what configuration means by it.

## Dependencies and consumers

- Depends on [[Std Time]] for `Duration` and `Instant`.
- Reached by [[Uses Human All]]; intended for configuration readers, logs, and command-line output.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[Uses Human All]]
