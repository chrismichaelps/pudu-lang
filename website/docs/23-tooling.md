# Tooling

Everything is one command: `pudu`. It checks, runs, tests, formats, and documents programs, and it speaks the language server protocol for editors.

## Commands

| Command | Does |
| --- | --- |
| `pudu run <file>` | compiles a program and runs its `main` |
| `pudu run --watch <file>` | runs it again whenever a source file changes |
| `pudu run --watch --also <path> <file>` | also runs it again when anything under a path changes — pages, data, styles |
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

## Watching a program

`pudu run --watch` starts a program again each time a `.pudu` file under its project changes, and each `--also` path adds everything under it: a site's pages, data, and stylesheets. The program is told it is being watched: `PUDU_WATCH` counts its starts from 1, and `PUDU_WATCH_CHANGED` names the files that changed before this start, one per line. A service can pass that on — this site's pages reload themselves when the count moves, and take new styles in place when a stylesheet is all that changed — with nothing to configure.

## Compiled modules are kept

Each module the compiler parses and checks without a diagnostic is kept, so the next `pudu run`, `pudu check`, or `pudu test` reads it instead of compiling it again — the standard library included. An entry is keyed by the module's text and everything it read, so an edit anywhere a module depends on compiles it again; nothing stale is ever used. Only clean products are kept, so every diagnostic comes from the compile reporting it.

The products live in the user's cache directory, `$XDG_CACHE_HOME/pudu` or `~/.cache/pudu`, under a directory named for the compiler that wrote them, so a different compiler reads none of them. `PUDU_CACHE` names another directory, and `PUDU_CACHE=off` turns keeping off. The cache is bounded and drops the entries used least recently.

## Editors

`pudu lsp` is the compiler answering an editor, so the editor and `pudu check` never disagree about what a program means. It gives:

- diagnostics as you type, with the same codes and help as the command line;
- hover with the inferred type, and for a name another module exports, that module's documentation;
- go to definition, into another module's file for an imported name, and to a module's file from its import;
- completion of a value's fields and methods, a module's exports after `Io.`, whole module paths after `import`, a selection's names inside `import Std.List { … }`, a match arm's variants after `case`, and a record literal's unset fields inside `Point{ … }`;
- signature help, references, rename, highlights, inlay hints for inferred types, the outline, workspace symbols, and formatting.

A document that is half written still gets answers: the server reads what it can of an unfinished line, and a request asked again at the same place is answered from what it already compiled. While it works it keeps reading, so a newer edit replaces an older one still waiting and a cancelled request stops its work.

The repository ships a VS Code extension in `editors/vscode` that runs the installed `pudu`. **Pudu: Restart Language Server** picks up a rebuilt compiler without reloading the window. The playground's editor asks the same server.
