---
type: module
path: "@root/src/Pudu/Eval/Io.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: SHALLOW
coupling: 1.0
interface_stability: 0.7
tags: [module, shallow]
aliases: [Eval Io]
---

# Eval Io

## Purpose

The effects a program may perform: its output, its input, the file system, its arguments and
environment, and a clock.

## Interface

### Signatures

```haskell
data IoOutcome a = IoDone !a | IoFailed !Text
writeStandardOutput, writeStandardError :: Text -> IO (IoOutcome ())
readStandardLine :: IO (IoOutcome (Maybe Text))
readTextFile :: FilePath -> IO (IoOutcome Text)
writeTextFile, appendTextFile :: FilePath -> Text -> IO (IoOutcome ())
testFileExists :: FilePath -> IO Bool
removeFileAt, createDirectoryAt :: FilePath -> IO (IoOutcome ())
listDirectoryAt :: FilePath -> IO (IoOutcome [Text])
programArguments :: IO [Text]
environmentPairs :: IO [(Text, Text)]
monotonicMilliseconds :: IO Integer
exitWith :: Integer -> IO ()
```

### Governance

- Every effect answers with an outcome rather than raising. The language has no exceptions, so a
  program that reads a missing file gets a `Result` and decides what to do; a runtime that unwound
  past a boundary the program cannot see would take away the only decision worth having.
- A failure carries **what the operating system said, unchanged**. A program reporting a failure to
  its own user is better served by the real reason than by one this module invented.
- **End of input is not a failure.** A program reading until there is no more is doing the ordinary
  thing, and reporting it as an error would make every such loop handle a failure that is not one.
  `readStandardLine` answers `Nothing`.
- **A question about the world is not a failure even when the answer is no.** `testFileExists`
  answers a plain truth value; a caller that wants to know *why* a path is unusable should try to
  use it.
- Output is **flushed**. A program that prints a prompt and then blocks on input has already shown
  the prompt; buffering that hid it would be a correctness problem, not a performance one.
- Creating a directory that exists succeeds. A caller writing into one wants it to be there, and
  making them check first would put a race between the check and the write.
- `exitWith` is the only effect that does not answer with an outcome: a program that asked to stop
  has nothing left to decide. A status outside the range an operating system carries is clamped
  rather than refused, because refusing would leave the program running.

### Linkage

- **Requires:** nothing in this project.
- **Consumed by:** [[Evaluator]].

## Algorithm

Thin wrappers over the platform, each catching `IOException` into an outcome.

## Negative Logic (Prohibited Paths)

- No exceptions crossing into evaluation.
- No message invented in place of the operating system's own.
- No effect performed while [[Compiler Pipeline]] folds constants; the evaluator refuses those
  before reaching here.

## Edge Cases

- A clock reading alone means nothing; only the difference between two does, which is why it is
  monotonic milliseconds rather than a calendar time.

## Depth

DEPTH 0.40 (SHALLOW by intent). It is the boundary, not a policy.

## Grill Log

- **Q:** Should effects raise and be caught by a language-level `try`? **A:** No. _Rationale:_
  [[architecture/SEMANTICS]] makes failure a value, and an exception would be a second failure
  mechanism with different rules — the thing `Result` exists to avoid. _Rejected:_ exceptions;
  a panic on any failed effect, which makes a missing file unrecoverable.
- **Q:** Should the clock report calendar time? **A:** Not from here. _Rationale:_ a calendar clock
  can move backwards between two reads, so a program timing itself with one can measure a negative
  duration. Calendar time needs a `Std.Time` with zones and a real date type. _Deferred:_ with
  [[architecture/STDLIB]]'s `Std.Time`.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]]
