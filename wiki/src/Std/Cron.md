---
type: module
path: "@root/lib/Std/Cron.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, time, schedule]
aliases: [Std Cron]
---

# Std Cron

## Purpose and interface

Five-field schedule expressions and the minutes they fire in, computed in UTC from
[[Std Time Format Civil]] day arithmetic with no clock or zone database.

Exports:
- `type CronError = FieldCount(Int) | Malformed(Str, Str) | OutOfRange(Str, Int, Int, Int) | UnknownMacro(Str)`.
- `type Schedule`: one membership table per field plus whether each day field was `*`.
- `parse(text: Str) -> Result[Schedule, CronError]`: five fields or `@yearly`, `@annually`,
  `@monthly`, `@weekly`, `@daily`, `@midnight`, `@hourly`. Fields take `*`, `n`, `a-b`, `*/s`,
  `a-b/s`, `a/s`, comma lists, month names `JAN`..`DEC`, weekday names `SUN`..`SAT`; weekday `7` is Sunday.
- `matches(schedule: &Schedule, moment: &Time.Instant) -> Bool`: whether the containing minute fires.
- `next(schedule: &Schedule, after: &Time.Instant) -> Option[Time.Instant]`: first firing minute
  strictly after `after`.
- `upcoming(schedule: &Schedule, after: &Time.Instant, count: Int) -> Array[Time.Instant]`.
- `explain(problem: &CronError) -> Str`.

## Semantics

- When both day-of-month and day-of-week are restricted, a day fires if either matches; when one is
  `*`, only the other decides. This is the conventional union rule, so `0 0 13 * FRI` fires on every
  Friday and every 13th.
- `next` walks days, rejecting a day by month and day fields before scanning its minutes, and skips
  whole hours whose hour bit is clear. It searches 3000 days, which covers every leap-day schedule;
  a schedule naming a date that never occurs (`0 0 30 2 *`) answers `None` rather than looping.

## Grill Log

- **Q:** Take a time zone? **A:** No. _Rationale:_ a zone needs a rules database the library does
  not carry, and a daylight-saving gap makes "the next 02:30" ambiguous; callers convert a UTC
  instant. _Rejected:_ a fixed-offset parameter that silently drifts across transitions.
- **Q:** Support seconds or years as sixth and seventh fields? **A:** No. _Rationale:_ the
  five-field form is what every scheduler and configuration file writes; extra fields change the
  meaning of existing expressions by position. _Rejected:_ optional positional fields.
- **Q:** Why a bounded search? **A:** An impossible date has no firing minute; a bound turns that
  into `None` instead of an endless loop, and 3000 days exceeds the eight-year leap cycle gap.

## Dependencies and consumers

- Depends on [[Std Time]] and [[Std Time Format Civil]].
- Consumed by `Std.App` schedules and by programs that plan recurring work.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]
