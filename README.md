# Pudu

A statically typed systems language. Predictable performance, explicit control,
no unchecked memory access in ordinary code.

Pre-release. Nothing here is a compatibility promise yet.

```pudu
module Sample

import Std.Io as Io
import Std.List as List

type Shape = Circle(Float) | Rect(Float, Float)

fn area(shape: Shape) -> Float {
  match shape {
    case Circle(r) => 3.14159 * r * r
    case Rect(w, h) => w * h
  }
}

export fn main() -> Int {
  let shapes = [Circle(1.0), Rect(2.0, 3.0)]
  let total = List.sumOr(&shapes.map(area), 0.0)

  match Io.read("notes.txt") {
    case Ok(text) => print(text)
    case Err(why) => printError("could not read: " + why)
  }

  shapes.length()
}
```

## Build

Needs GHC 9.10 or later and cabal 3.12 or later. CI builds on 9.14.1.

```bash
cabal build all
```

The binary lands under `dist-newstyle/`; `cabal run pudu -- <args>` invokes it.

To install or refresh the exact executable used by the shell and editor:

```bash
mkdir -p "$HOME/.local/bin"
cabal install exe:pudu --installdir="$HOME/.local/bin" --overwrite-policy=always
hash -r
pudu check test-fixtures/tooling/RecentLanguage.pudu
node test/lsp-session.mjs "$(command -v pudu)"
```

The behavioral checks matter while development builds share version `0.1.0.0`:
version text alone cannot distinguish a current compiler from an older installed copy.

```bash
cabal test all --test-show-details=direct
```

Local work uses the unoptimized profile. Release validation adds
`--enable-optimization=2`, and CI builds with `-Werror` before anything else —
a fresh checkout has nothing built, so that check cannot pass vacuously.

## Use

```
pudu                 start puduci, the interactive session
pudu repl [file]     start puduci, optionally loading a file
pudu check <file>…   compile and report diagnostics
pudu run <file>      compile and run main
pudu explain <file>  run, and report what running it cost
pudu fmt <file>…     rewrite in the one committed style
pudu doc <file>…     describe every name a program declares
pudu search <query>  find a name, or a type shape like 'Array[a] -> a'
pudu lsp             speak LSP over stdio
```

`fmt` takes `--check` (report, change nothing) and `--stdout`. `doc` takes
`--json` and `--html`; the HTML page is self-contained and searchable.

At the prompt:

```
puduci> 1 + 1
2
puduci> :t "hello"
"hello" :: Str
```

`:?` lists the rest — `:load`, `:browse`, `:info`, `:instances`, `:doc`,
`:search`, `:set +t` for types after each result, `:set +s` for timings.

## Editor

`editors/vscode` is a thin client over `pudu lsp`. Set `pudu.serverPath` if the
compiler is not on `PATH`. Diagnostics, hover, completion — including methods
after a dot, both built-in and ones your `impl` blocks declare.

## What is here

- **Types** — inference with declared boundaries, generics with trait bounds,
  sum types with named payloads, records, tuples, traits and `impl` blocks,
  `dynamic Trait` for a value whose type is not named.
- **Failure is a value.** No exceptions. Effects answer `Result[T, Str]`
  carrying what the operating system said.
- **Exhaustiveness** is checked; a `match` that misses a case is an error, not a
  runtime surprise.
- **Compile-time folding** runs the evaluator with effects denied. A constant
  that tries to reach the world is `E7009`.
- **Std** — 26 modules: `Io`, `Env`, `Text`, `List`, `Map`, `Set`, `Iter`,
  `Json`, `Http`, `Url`, `Time`, `Math`, `Decimal`, `Crypto`, `Process`,
  `Random`, and the rest under [`lib/Std`](lib/Std).

Every diagnostic has a code and a stable meaning: `E0xxx` lexing, `E1xxx`
parsing, `E2xxx` names, `E3xxx` types, `E5xxx` exhaustiveness, `E7xxx` runtime.

## Not here yet

Streaming — files are read whole into memory, so multi-gigabyte inputs will not
work. Native code generation; today the compiler type-checks and interprets.

## Layout

```
src/Pudu/        the compiler — frontend, semantic, type, eval, lsp, repl
lib/Std/         the standard library, written in Pudu
test/            the property suite and the node-driven checks
test-fixtures/   programs the suite compiles and runs end to end
wiki/            the normative documentation
editors/vscode/  the editor client
```

The repository is governed wiki-first: [`wiki/00-INDEX.md`](wiki/00-INDEX.md) is
the entry point, the static and dynamic rules are normative in
[`wiki/architecture/SEMANTICS.md`](wiki/architecture/SEMANTICS.md), and the
workflow is in
[`wiki/architecture/DELIVERY.md`](wiki/architecture/DELIVERY.md). Syntax not
represented there is not a promise.

Read [`CONTRIBUTING.md`](CONTRIBUTING.md) before proposing a language or
compiler change.

## License

Apache 2.0 with the LLVM exception ([`LICENSE`](LICENSE)).

Writing programs in Pudu and shipping them requires nothing of you — the
exception waives attribution for the standard library code the compiler embeds
in your binary, and makes what Pudu produces linkable into GPLv2 programs. The
licence governs the compiler and the standard library themselves: contributing
to them, forking them, redistributing them.
