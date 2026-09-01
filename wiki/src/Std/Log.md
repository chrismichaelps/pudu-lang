---
type: module
path: "@root/lib/Std/Log.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.4
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.7
tags: [module, stdlib, medium]
aliases: [Std Log]
---

# Std Log

## Purpose

Let a program say what it is doing in a way that survives nobody watching: with a level so it can be
turned down, a name so it can be told apart, fields so it can be searched, and a format so the same
lines can be read by a person or by whatever collects them.

## Interface

36 exports: the `Level`, `Field`, `Line`, `Format`, and `Logger` types; construction (`stdout`,
`stderr`); the builders (`keeping`, `named`, `under`, `carrying`, `carryingValue`, `shapedBy`,
`through`); the readers (`leastOf`, `nameOf`, `fieldsOf`, `keeps`, `levelName`, `levelFrom`); the
formats (`logfmt`, `pretty`, `json`, and `quoted` for anyone writing their own); the pure `lineOf`,
`rendered`, and `stamped`; and the writing side (`at`, `atMoment`, `debug`, `info`, `warn`, `error`,
`fatal`, `field`, `failure`).

### Governance

- **Making a line is separate from writing it.** `rendered` and `stamped` answer exactly the text a
  write produces, so every configuration is checked by comparing values rather than by capturing
  output — the same division [[Std Out]] draws, and for the same reason.
- A logger is a **value**. A library that logs takes the logger to log through rather than choosing a
  stream its caller did not pick.
- **A format is a function on a `Line`**, not a set of options on the logger. The three provided
  formats have no privileged access: a format nobody anticipated is a function a program writes.
- **Every part of a `logfmt` line is a pair, message included.** A message left outside the pairs is
  the one part a reader has to find by counting words from the left, and position is what breaks when
  a field is added.
- **Fields are carried, not passed.** A request identifier is attached once where the request is
  known, so the lines that mention it later cannot forget it.
- **Fields keep the order they were written**, and a repeated key keeps both entries. A log records
  what happened rather than reconciling it.
- **Levels are ordered, so a threshold is a comparison** rather than a set. A logger keeping `Warn`
  keeps `Error` and `Fatal`; a program turned down to its warnings has not asked to stop hearing
  about failures.
- **The time is given, never read from a clock.** A line is a pure function of what it was told, so
  two runs of the same program produce comparable output.
- The default keeps everything from `Info` up. A default that says everything trains a reader to
  ignore the output, and the one thing a log must not be is ignored.
- No partial functions, and every write answers `Result`.

### Linkage

- **Requires:** [[Std Out]] for the stream and the writing, [[Std Text]] for joining and for the
  character scan behind escaping.
- **Consumed by:** programs.

## Algorithm

`lineOf` gathers the logger's name and fields with the level, message, and supplied moment into a
`Line`. `rendered` and `stamped` apply the logger's format to it. `at` asks `keeps` first and writes
through the printer only when the line survives the threshold.

`quoted` writes a value bare when nothing in it could confuse a reader, and otherwise in quotes with
`escaped` applied. `escaped` answers text with nothing to escape unchanged, so the character-by-
character pass is taken only by the text that needs it.

## Negative Logic (Prohibited Paths)

- No clock. A logger that stamped its own lines could not be checked by comparing values, and would
  put a hidden effect in every call.
- No format strings, here or anywhere; [[architecture/STDLIB]] settles that typed formatting is
  [[Std Fmt]]'s.
- No global logger and no ambient configuration. What a line carries is what the logger it was made
  from carries, and that is visible at the call site.
- No writing at `Silent`. It names a threshold rather than a line.
- No sorting of fields, which would scatter related keys away from the order a reader follows.
- No guessing at types in `json`: every value is written as a string, because a field holding `00123`
  or a version is not a number and a reader that guesses will eventually guess wrong.

## Edge Cases

- A part that is empty is left out rather than written as nothing, so a line with no name carries no
  `logger=`. `json` is the exception for `message`, which is always present so every object has the
  same shape.
- A value carrying a space, a quote, an equals sign, a backslash, or a control character is quoted,
  and the character escaped. Otherwise `note=see below` reads as a field and a stray word.
- A control character with no short spelling is written as its number, so text the program was handed
  cannot end a line or an object early.
- `carryingValue` takes the quotes `show` puts around text back off. How a value is delimited is the
  format's decision, and `show` renders for source rather than for a field.
- A line filtered by the threshold is still a success. Nothing went wrong; there was just nothing to
  write.
- Every builder answers a new logger and leaves the one it was given alone.

## Depth

DEPTH 0.40 (MEDIUM). One line-building rule, a comparison for the threshold, and three formats that
only change how the same parts read.

## Grill Log

- **Q:** Why a logger value rather than module-level functions on an ambient configuration, which is
  what most languages provide? **A:** Because Pudu has no mutable global state, and because the
  ambient version hides what a line will carry from the place that writes it. _Rationale:_ a value
  makes "log through this" an ordinary parameter, which is what lets a library log without choosing
  its caller's stream. _Rejected:_ a configured singleton, which cannot be two things at once when
  one part of a program wants debug output and another does not.
- **Q:** Why is the message a pair in `logfmt` rather than trailing text, which reads more easily?
  **A:** Because a trailing message is found by position, and position moves when a field is added.
  _Rationale:_ every part being a pair is what makes the line parseable without knowing which fields
  the program happened to carry; `pretty` exists for the reader who wants the eye-scannable form.
  _Rejected:_ one format trying to serve both, which serves neither.
- **Q:** Why does the caller supply the timestamp instead of the logger reading a clock? **A:**
  Because a clock inside `rendered` would make it impure and make the module untestable by
  comparison. _Rationale:_ reading the clock is one line at the edge of a program, and passing the
  answer keeps every line a function of what it was told. _Rejected:_ a clock held on the logger,
  which only moves the effect rather than removing it.
- **Q:** Why is `Silent` a `Level` rather than a separate switch? **A:** Because "off" is a threshold
  like any other, and a separate flag is a second thing to check and a second thing to forget.
  _Rationale:_ it also lets `levelFrom` answer a setting that says `off` or `none`, which is how
  turning logging off is actually spelled in configuration. _Rejected:_ `Option[Level]` for the
  threshold, which pushes the same case into every caller.
- **Q:** Should a repeated field key replace the earlier one? **A:** No. _Rationale:_ a log records
  what happened, and two attempts under the same key are two facts; collapsing them loses the first.
  _Rejected:_ last-wins, which is what a configuration map should do and not what a record should.
- **Q:** Why does `escaped` scan before it rewrites, rather than always rewriting? **A:** Because
  nearly all text has nothing to escape, and the character-by-character path builds a new string for
  every character. _Rationale:_ the scan answers on the first character that needs it, so the common
  line pays a read and no allocation. _Rejected:_ an unconditional rewrite, which charges every line
  for the rare one.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[Std Out]]
