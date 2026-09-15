# Tooling

Everything is one command: `pudu`. It checks, runs, tests, formats, and documents programs, and it speaks the language server protocol for editors.

## Commands

| Command | Does |
| --- | --- |
| `pudu run <file>` | compiles a program and runs its `main` |
| `pudu run --watch <file>` | runs it again whenever a source file changes |
| `pudu check <file>...` | compiles files and reports diagnostics without running them |
| `pudu test [path]...` | discovers and runs test programs |
| `pudu fmt <path>...` | rewrites files in the one supported format |
| `pudu fmt --check <path>...` | reports unformatted files without changing them |
| `pudu lint <path>...` | analyzes programs, with `--fix` for safe fixes |
| `pudu doc <file>...` | describes every name a program declares, as text, `--json`, or `--html` |
| `pudu search <query> <file>...` | finds a name, or a type shape such as `Array[a] -> a` |
| `pudu build <file>` | writes one file that runs anywhere the compiler runs |
| `pudu init [path]` | creates a project with a `pudu.toml` manifest |
| `pudu explain <file>` | runs a program and reports what running it cost |
| `pudu repl [file]` | starts the interactive session |
| `pudu lsp` | speaks the language server protocol over standard input and output |
| `pudu version` | prints the version |

## Formatting

There is one format, and `pudu fmt` writes it: two-space indentation, braces on the line that opens them, and trailing commas in multiline lists. The formatter only moves whitespace — the tokens it writes are the tokens it read — so formatting never changes what a program means. `pudu fmt --check` makes a good gate in continuous integration.

## Tests

A test program is an ordinary module whose `main` builds a suite with `Std.Test` and reports it:

```pudu
module MathTest

import Std.Test as Test

fn double(n: Int) -> Int = n * 2

export fn main() -> Int {
  let suite = Test.suite("math", &[
      Test.that("doubling adds a number to itself", double(21) == 42),
      Test.not("doubling is not squaring", double(3) == 9)
    ])
  Test.report(&Test.run(&suite))
}
```

`pudu test` discovers test programs under the paths it is given and runs each one.

## Diagnostics

Every diagnostic has a code, such as `E3033` for calling a member a module does not export. The code names one kind of mistake, and the message says where it happened and how to fix it.

## Editors

`pudu lsp` gives editors diagnostics as you type, hover documentation from `///` comments, go to definition, completion, and formatting. The repository ships a VS Code extension in `editors/vscode` that runs the installed `pudu`.
