# Files and the system

Programs read files, write output, and ask the machine questions. In Pudu every one of those can fail, so every one returns a `Result`, and nothing reaches the outside world except through a standard library call you can see.

## Output

`Std.Io` writes to the program's standard output and error output:

```pudu
module Report

import Std.Io as Io

fn main() -> Int {
  let lines = ["name   score", "ada       95", "grace    100"]
  match Io.writeLines(&lines) {
    case Ok(_) => 0
    case Err(problem) => {
      let _reported = Io.writeErrorLine("could not write the report: {problem}")
      1
    }
  }
}
```

| Function | Writes |
| --- | --- |
| `Io.writeLine(text)` | one line to standard output |
| `Io.writeLines(&lines)` | several lines, stopping at the first failure |
| `Io.writeErrorLine(text)` | one line to standard error |
| `Io.writeValue(value)` | any value, rendered as text |

## Reading and writing files

A whole file is read with `Io.read` and written with `Io.write`. Both use plain text paths and answer a `Result` whose error says what went wrong:

```pudu
module Notes

import Std.Env as Env
import Std.Io as Io

fn keepNotes(path: Str) -> Result[Int, Str] {
  Io.write(path, "first note\n") ?
  Io.appendLine(path, "second note") ?
  let lines = Io.readLines(path) ?
  let text = Io.read(path) ?
  Io.remove(path) ?
  if text.contains("second") { Ok(lines.length()) } else { Err("the note was not kept") }
}

fn main() -> Int {
  let path = Io.join(Env.temporaryDirectory(), "pudu-notes-example.txt")
  match keepNotes(path) {
    case Ok(count) => if count == 2 && !Io.exists(path) { 0 } else { 1 }
    case Err(_) => 1
  }
}
```

Because every call answers a `Result`, `?` gives a function a straight line through the steps that stops at the first one that fails.

## Large files

`Io.read` holds a whole file in memory. For a file that may be large, fold over it one line at a time instead; only the current chunk is ever held:

```pudu
module Totals

import Std.Env as Env
import Std.Io as Io
import Std.Option as Option
import Std.Text as Text

fn main() -> Int {
  let path = Io.join(Env.temporaryDirectory(), "pudu-totals-example.txt")
  let prepared = Io.writeFileLines(path, &["10", "20", "not a number", "12"])
  if prepared != Ok(()) { return 1 }
  let summed = Io.foldLines(path, 0, fn(total: Int, line: Str) => total + Option.unwrapOr(Text.wholeOf(line), 0))
  let _removed = Io.remove(path)
  if summed == Ok(42) { 0 } else { 1 }
}
```

`Io.forEachLine` does the same when there is nothing to accumulate, and `Std.Json.foldLines` and `Std.Csv.foldRows` read structured files the same way.

## Paths

`Std.Path` builds and takes apart paths without touching the filesystem:

```pudu
module Paths

import Std.Path as Path

fn main() -> Int {
  let report = Path.joinAll(&["reports", "2026", "summary.csv"])
  let checks = [
    Path.nameOf(report) == "summary.csv",
    Path.stemOf(report) == "summary",
    Path.extensionOf(report) == Some("csv"),
    Path.withExtension(report, "json").endsWith("summary.json"),
    Path.normalize("reports/./2026/../2027") == Path.join("reports", "2027")
  ]
  if checks.filter(fn(held: Bool) => !held).isEmpty() { 0 } else { 1 }
}
```

## Directories

| Function | Does |
| --- | --- |
| `Io.list(directory)` | the names a directory holds |
| `Io.listPaths(directory)` | the same names, joined to the directory |
| `Io.makeDirectory(path)` | creates a directory and any parents it needs |
| `Io.exists(path)` | whether something is there |
| `Fs.metadata(path)` | size, kind, and permissions |
| `Fs.removeTree(path)` | removes a directory and everything under it |
| `Fs.writeTextAtomically(path, text)` | replaces a file so no reader ever sees it half written |

## The environment

`Std.Env` answers questions about how the program was started:

```pudu
module Settings

import Std.Env as Env
import Std.Option as Option
import Std.Text as Text

fn portSetting() -> Int {
  let written = Env.variableOr("PUDU_EXAMPLE_PORT", "8080")
  Option.unwrapOr(Text.wholeOf(written), 8080)
}

fn main() -> Int {
  let verbose = Env.hasFlag("--verbose")
  let started = Env.elapsedMilliseconds()
  if portSetting() > 0 && (verbose || !verbose) && started >= 0 { 0 } else { 1 }
}
```

| Function | Answers |
| --- | --- |
| `Env.all()` | every argument |
| `Env.at(position)` | one argument, or `None` |
| `Env.hasFlag(flag)` | whether an exact argument was given |
| `Env.option(name)` | the value after a named argument, as in `--port 80` |
| `Env.variable(name)` | an environment variable, or `None` |
| `Env.variableOr(name, fallback)` | an environment variable, or a fallback |

For a program with many options, [Std.Args](/module/Std.Args) declares them, checks them, and writes the help text.

## Other programs

[Std.Process](/module/Std.Process) starts other programs, writes to their input, and reads their output, with the same `Result` on every step.
