---
type: module
path: "@root/src/Pudu/Eval/Clock.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: SHALLOW
coupling: 1.0
interface_stability: 0.7
tags: [module, shallow]
aliases: [Eval Clock]
---

# Eval Clock

## Purpose

Calendar time and subprocesses: the two effects that need the platform to answer rather than the
file system.

## Interface

### Signatures

```haskell
currentInstant :: IO Integer
formatInstant :: Text -> Integer -> Text -> IO (Either Text Text)
parseInstant :: Text -> Text -> Either Text Integer
timeZoneOffset :: IO Integer
data ProcessOutcome = ProcessOutcome { processStatus :: !Integer, processOutput, processErrors :: !Text }
runProcess :: FilePath -> [Text] -> Text -> IO (Either Text ProcessOutcome)
```

### Governance

- An instant is **milliseconds since the start of 1970**. Milliseconds rather than seconds, because a
  program measuring anything shorter would otherwise need a second clock; not nanoseconds, because
  the language's integers are the ones a reader writes and a nanosecond count is not one of those.
- This clock can move **backwards** when the system's is adjusted. That is what makes it the wrong
  one for measuring a duration, and why the monotonic clock in [[Eval Io]] exists beside it.
- The pattern vocabulary is the **platform's**. A reader who knows `%Y-%m-%d` should not have to
  learn a second spelling of it, and inventing one would mean documenting it forever.
- Only `utc` and `local` are named as zones. A full zone database is a data dependency this compiler
  does not carry, and answering for `Europe/Madrid` without one would be answering wrongly.
- A subprocess's **non-zero status is not a failure of running it**. The program ran, and what it
  decided is the answer; only being unable to run it at all fails. A caller that wants a non-zero
  status treated as failure says so — `Std.Process.output` does.
- Both streams are captured rather than inherited. A caller that wanted them inherited would not be
  asking for them back, and one that gets them can print them itself.
- A finished program answers as a **tuple**, not a record. A record would need a wired-in nominal
  type with wired-in fields — a second way for the compiler to know about a shape, for one built-in.
  `Std.Process` gives the parts names, in the language, where a reader can see them.

### Linkage

- **Requires:** nothing in this project.
- **Consumed by:** [[Evaluator]].

## Algorithm

Thin wrappers over the platform's time formatting and process running, each catching failure into an
`Either`.

## Negative Logic (Prohibited Paths)

- No zone database, and no guess in place of one.
- No inherited streams, and no shell interpretation of a program's name: the program is run, not a
  command line parsed.
- No effect performed while [[Compiler Pipeline]] folds constants.

## Edge Cases

- A pattern that renders nothing is not an error; a caller asking for `%%` gets a per-cent sign.
- Parsing reports the **pattern** rather than the text, because a caller with a thousand lines to
  read wants to know which of the two is wrong and only the pattern is theirs.

## Depth

DEPTH 0.40 (SHALLOW by intent). It is a boundary, not a calendar.

## Grill Log

- **Q:** Should an instant be a distinct runtime type rather than a number? **A:** Not in the
  runtime. _Rationale:_ the distinction that matters — an instant is not a duration and not a date —
  is worth having in the *language*, where `Std.Time` gives each its own type and a reader sees the
  mistake at compile time. A third runtime representation would buy nothing the library does not
  already provide. _Rejected:_ a wired-in `Instant` value.
- **Q:** Should `runProcess` take a command line to be split? **A:** No. _Rationale:_ splitting a
  command line means implementing a shell's quoting rules, and every place that has done so has an
  injection bug named after it. The program and its arguments are separate because that is what
  makes them unambiguous. _Rejected:_ a single command string.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]] · [[Eval Io]]
