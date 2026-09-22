# Introduction

Pudu is a statically typed programming language for programs that are easy to read, safe to change, and honest about failure. What a function takes, what it gives back, whether it can fail, and whether it changes what it was given are all written in its signature, so a reader can tell what code promises without reading its body.

> Pudu is pre-release (0.1.0). Programs run on an interpreter, dependencies are local directories, and the language and its standard library may still change before a stable release.

## What Pudu looks like

```pudu
module Hello

import Std.Io as Io

fn main() -> Int {
  let _written = Io.writeLine("Hello from Pudu!")
  0
}
```

Every file names its module, imports what it uses, and declares what it exports. A program starts at `main`, and the whole number `main` returns is the program's exit status.

## Install

No binary release has been published yet. Pudu builds from source with GHC 9.10 or later and Cabal 3.12 or later:

```sh
git clone https://github.com/chrismichaelps/pudu-lang.git
cd pudu-lang
cabal install exe:pudu --installdir="$HOME/.local/bin" --overwrite-policy=always
pudu version
```

The installed `pudu` carries its standard library, so nothing else needs to be installed beside it. macOS and Linux x86-64 are tested; Windows is not.

## Run your first program

Save the program above as `Hello.pudu` and run it:

```sh
pudu run Hello.pudu
```

To start a project with its own manifest, source directory, and tests:

```sh
pudu init hello
cd hello
pudu run src/Main.pudu
pudu test
```

## What Pudu is built around

- **Failure is a value.** A function that can fail returns `Result[T, E]`, and the caller decides what happens. There are no exceptions.
- **Absence is a value.** `Option[T]` holds `Some(value)` or `None`. Ordinary types never hold `null`.
- **Change is visible.** `let` never changes, `var` may, and `&mut T` marks the one place allowed to change a borrowed value.
- **Patterns are checked.** A `match` must cover every shape a value can have.
- **Imports are explicit.** There are no wildcard imports, so every name's origin is in the import list.

## How this documentation is organised

The chapters are written to be read in order, each building on the ones before it:

1. **Starting out** — [getting started](/docs/getting-started), [basics](/docs/basics), [functions](/docs/functions), [types](/docs/types), and [numbers](/docs/numbers).
2. **Working with data** — [text](/docs/text), [collections](/docs/collections), [control flow](/docs/control-flow), and [errors](/docs/errors).
3. **Structuring programs** — [ownership](/docs/ownership), [modules and packages](/docs/modules), [traits](/docs/traits), [generics](/docs/generics), and [compile time and macros](/docs/compile-time).
4. **Building real software** — [testing](/docs/testing), [files and the system](/docs/files), [data formats](/docs/data-formats), [HTTP](/docs/http), [concurrency](/docs/concurrency), and [unsafe and foreign code](/docs/foreign-code).
5. **Reference** — the [standard library](/docs/standard-library) map and [tooling](/docs/tooling).

Every example is a complete program. Copy one into a file named after its module, run it with `pudu run`, and change it to see what happens. If you already know what you are looking for, the [API reference](/modules) lists everything a program can import.
