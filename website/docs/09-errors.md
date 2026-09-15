# Errors

Pudu has no exceptions. Work that can fail says so in its type, and the caller decides what happens next.

## Result

A function that can fail returns `Result[T, E]`: `Ok(value)` when it succeeded and `Err(problem)` when it did not. The problem can be any type, and a sum type of the ways the work can fail is usually the most useful one:

```pudu
module Settings

import Std.Io as Io
import Std.Text as Text

type SettingError = | Missing(Str) | NotANumber(Str)

fn portFrom(text: Str) -> Result[Int, SettingError] {
  if text.isEmpty() { return Err(Missing("port")) }
  match Text.wholeOf(text) {
    case Some(port) => Ok(port)
    case None => Err(NotANumber(text))
  }
}

fn address(host: Str, port: Str) -> Result[Str, SettingError] {
  let number = portFrom(port) ?
  Ok("{host}:{number}")
}

fn main() -> Int {
  match address("127.0.0.1", "8080") {
    case Ok(text) => {
      let _written = Io.writeLine(text)
      0
    }
    case Err(Missing(name)) => {
      let _written = Io.writeLine("missing {name}")
      1
    }
    case Err(NotANumber(text)) => {
      let _written = Io.writeLine("not a number: {text}")
      1
    }
  }
}
```

## The ? operator

A `?` after a `Result` gives the value inside `Ok`, or returns the `Err` from the current function straight away. In `address` above, `portFrom(port) ?` either yields the port or ends `address` with the same error.

`?` works the same way on `Option` inside a function that returns `Option`: `Some(value)?` gives the value, and `None?` returns `None`. Which one is meant comes from the function's own return type.

```pudu
module Chains

import Std.Text as Text

fn sum(left: Str, right: Str) -> Option[Int] {
  let a = Text.wholeOf(left) ?
  let b = Text.wholeOf(right) ?
  Some(a + b)
}

fn main() -> Int {
  if sum("2", "40") == Some(42) && sum("2", "x") == None { 0 } else { 1 }
}
```

## Working with results

`Std.Result` and `Std.Option` hold the helpers for the common cases:

| Helper | Does |
| --- | --- |
| `Result.unwrapOr(result, fallback)` | the value, or a fallback when it failed |
| `Result.mapErr(result, change)` | the same result with its error changed |
| `Result.isOk(&result)` | whether it succeeded |
| `Option.unwrapOr(option, fallback)` | the value, or a fallback when it is absent |

## Effects return results too

Reading a file, writing output, reading an environment variable, and every other effect answers a `Result` rather than stopping the program. That is why the examples in these pages write `let _written = Io.writeLine(...)`: the name makes it visible that the result of writing was received and deliberately set aside.

## Panics

A panic stops the program. It is reserved for a broken internal invariant — an index outside an array, a fixed-width number that no longer fits — never for an ordinary failure such as a missing file or bad input. Anything a caller could reasonably handle is a `Result`.
