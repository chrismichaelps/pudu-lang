<p align="center">
  <img src="public/pudu-lang-full-logo.png" alt="Pudu" width="800">
</p>

# Pudu

Pudu is a statically typed, expression-oriented programming language for services, tools, and
native applications. Failure is a value, absence is explicit, pattern matching is exhaustive, and
code that steps outside the language's guarantees is confined to named capability regions. The
standard library is written in Pudu and checked by the same compiler as your program.

One executable is the whole toolchain: it checks, runs, tests, formats, lints, documents, bundles,
answers an interactive session, and serves your editor over the Language Server Protocol.

> **Status: pre-release, version 0.1.0.** The language, compiler, standard library, and tooling
> described here are implemented and tested on every change, and the first release is being
> prepared. Programs are interpreted; native code generation, a package registry, and a 1.0
> compatibility promise do not exist yet. See [Status and limitations](#status-and-limitations).

## A first look

```pudu
module Tour

import Std.Io as Io
import Std.Text as Text

/// A shape is one of a closed set of cases.
type Shape
  = Circle(Float)
  | Rectangle(Float, Float)

/// Every case is handled, or the program does not compile.
fn area(shape: Shape) -> Float {
  match shape {
    case Circle(radius) => 3.14159 * radius * radius
    case Rectangle(width, height) => width * height
  }
}

type Order = { item: Str, quantity: Int }

/// Failure is a value: `?` returns the error to the caller.
fn parseOrder(line: Str) -> Result[Order, Str] {
  let parts = line.split(",")
  if parts.length() != 2 { return Err("expected item,quantity") }
  let Some(quantity) = Text.countOf(parts[1].trim()) else { return Err("quantity is not a number") }
  Ok(Order{item: parts[0].trim(), quantity: quantity})
}

fn total(lines: &Array[Str]) -> Result[Int, Str] {
  var sum = 0
  for line in lines {
    let order = parseOrder(line) ?
    sum = sum + order.quantity
  }
  Ok(sum)
}

export fn main() -> Result[(), Str] {
  Io.writeLine("area " + show(area(Rectangle(3.0, 4.0)))) ?
  let count = total(&["pencil, 3", "paper, 12"]) ?
  Io.writeLine("items " + show(count)) ?
  match parseOrder("pencil, many") {
    case Ok(_) => Io.writeLine("unexpected") ?
    case Err(reason) => Io.writeLine("refused: " + reason) ?
  }
  Ok(())
}
```

```console
$ pudu run Tour.pudu
area 12.0
items 15
refused: quantity is not a number
```

## Design

- **Effects answer with `Result`.** There are no exceptions to catch: a file that cannot be read,
  a connection that is refused, and text that is not a number all come back as values the caller
  must handle or pass on with `?`.
- **Absence is `Option`.** There is no null. `let … else`, `if let`, and `while let` bind a value
  only where it is present.
- **Exhaustive matching.** Sum types are closed, and a `match` that forgets a case does not compile.
- **Arithmetic never wraps silently.** `Int` is a 64-bit integer and `Int8` through `UInt64` hold
  their declared widths; a result that does not fit is an error, and wrapping or saturating
  arithmetic is written explicitly. `Float32`/`Float64` sit beside an exact `Decimal`, in which
  `0.1d + 0.2d` is `0.3`.
- **Traits and generics**, including higher-kinded type parameters, with coherence and orphan checks.
- **Capability-scoped `unsafe`.** Calling a foreign library requires the `foreign` capability, and a
  wrapper that takes that responsibility once relieves its callers of it.
- **Diagnostics are part of the language.** Every error has a stable code, a precise span, and help
  that says what to do next.

## Install

No prebuilt release has been published yet, so the compiler is built from source. It requires GHC
9.10 or later and Cabal 3.12 or later; CI uses GHC 9.14.1.

```bash
git clone https://github.com/chrismichaelps/pudu-lang.git
cd pudu-lang
cabal install exe:pudu --installdir="$HOME/.local/bin" --overwrite-policy=always
export PATH="$HOME/.local/bin:$PATH"
pudu --version
```

An installed `pudu` carries its standard library with it. To use a library in another location, set
`PUDU_LIB` to that directory.

When working on the compiler itself, `scripts/refresh-install.sh` rebuilds and replaces the installed
executable, then proves the binary your shell resolves with `pudu check`, a REPL probe, and a real
language-server session. It stops if an older `pudu` earlier on `PATH` would shadow the new one.

## Quick start

```bash
pudu init hello
cd hello
pudu run src/Main.pudu
pudu test
```

`pudu init` creates a project whose dependencies point inward — `Main` composes effects, `App` owns
use cases, and `Domain` holds pure rules:

```text
hello/
├── pudu.toml
├── README.md
├── src/
│   ├── Main.pudu
│   ├── App/Greeting.pudu
│   └── Domain/Greeting.pudu
└── test/
    └── App/GreetingTest.pudu
```

The manifest names the package, its version, the language versions it accepts, and where its
modules live:

```toml
[package]
name = "hello"
version = "0.1.0"
language = ">=0.1.0 <0.2.0"
source = "src"

[dependencies]
src = "src"
```

A dependency is another directory of Pudu source named by path. Nothing is fetched from the network.

## Toolchain

| Command | What it does |
| --- | --- |
| `pudu check <file>...` | Compile and report diagnostics without running. |
| `pudu run <file>` | Compile a program and run its `main`; `--watch` reruns on every change. |
| `pudu test [path]...` | Discover and run test suites. |
| `pudu fmt <path>...` | Format files in place; `--check` reports unformatted files and changes none. |
| `pudu lint [--json] [--fix] <path>...` | Named, suppressible findings with source-verified safe fixes. |
| `pudu build <file> [-o name]` | Write one executable holding the program, every module it uses, and the runtime. |
| `pudu doc <file>...` | Describe every declared name; `--html` emits a searchable documentation page, `--json` an index. |
| `pudu search <query> <file>...` | Find a declaration by name or by type shape, such as `'Array[a] -> a'`. |
| `pudu explain <file>` | Run a program and report the evaluation work it performed. |
| `pudu repl [file]` | Interactive session, optionally with a file loaded. |
| `pudu lsp` | Language server over stdio. |
| `pudu init [path]` | Create a project. |

A bundle from `pudu build` runs on a machine with nothing installed:

```bash
pudu build src/Main.pudu -o service
./service
```

## Standard library

The standard library is 173 Pudu modules under the `Std` namespace, resolved without any
declaration in your manifest. Highlights:

| Area | Modules |
| --- | --- |
| Core values | `Option`, `Result`, `List`, `Map`, `Set`, `Text`, `Char`, `Bytes`, `Num`, `Decimal`, `Math`, `Iter` |
| Collections | `HashMap`, `SortedMap`, `LinkedMap`, `MultiMap`, `BiMap`, `Deque`, `Heap`, `Tree`, `Graph`, `PrefixTrie`, `LruCache`, `RingBuffer`, `BitSet`, `BloomFilter` |
| Files and processes | `Io`, `Fs`, `Path`, `Glob`, `Process`, `Env`, `Signal`, `Time` |
| Formats | `Json`, `Toml`, `Yaml`, `Csv`, `Xml`, `Html`, `Mime`, `Url`, `Diff`, `Semver`, `Uuid`, `Archive.Tar`, `Archive.Zip`, `Compress.Gzip` |
| Networking | `Net`, `Tls`, `Http`, `Http.Client`, `Http.Server`, `Mail.Smtp` |
| Data | `Db` with `Db.Sqlite` and `Db.Postgres`, migrations, repositories, and typed rows |
| Concurrency | `Concurrent`, `Channel`, `Sync`, `RateLimiter` |
| Security | `Crypto` (SHA-2, SHA-3, BLAKE2b, HMAC, constant-time comparison), `Random`, `App.Jwt`, `App.Password`, `App.Totp` |
| Applications | `App` for configuration, sessions, health, metrics, and tracing; `Log`, `Test`, `Bench` |
| Native media | `Ui.Canvas`, `Ui.Layout`, `Ui.Screen`, `Ui.Text`, `Ui.Desktop`, `Audio`, `Audio.Graph`, `Audio.Device`, `Video` |

File readers stream: `Io.foldLines` and `Io.foldChunks` hold one chunk at a time, and a gate checks
that their peak memory is the same at ten times the input.

## Editor support

`pudu lsp` provides diagnostics, hover, go to definition, references, rename, completion, signature
help, semantic tokens, inlay hints, code actions, and formatting — all answered by the compiler, so
the editor and the command line cannot disagree. A VS Code extension lives in
[`editors/vscode`](editors/vscode); any editor with a language-server client can run `pudu lsp`
directly.

## Platforms

| Platform | Status |
| --- | --- |
| macOS (Apple silicon) | Primary development platform. The full toolchain, including native desktop windows and audio output. |
| Linux x86-64 | Built and tested by CI on every push and pull request to `dev` and `main`; a separate workflow builds a static musl runtime. Desktop and audio device operations answer `UnsupportedPlatform`. |
| Windows | Not yet built or tested. |

## Examples

[`examples/`](examples) holds complete programs: a SQLite/PostgreSQL web service, a layered
full-stack application, database access and reporting, a media studio that renders audio and video to
a real window, and a foreign-library binding that draws with raylib. See
[`examples/README.md`](examples/README.md) for how to run each one.

## Status and limitations

Pudu is ready to evaluate and to build real programs with, and not yet ready to promise
compatibility. Known gaps before a stable release, tracked in
[`wiki/architecture/RELEASE-READINESS.md`](wiki/architecture/RELEASE-READINESS.md):

- **Execution** is by interpreter. `pudu build` bundles the runtime, so deployment is one file, but
  there is no native code generation.
- **Packages** are local directories. There is no registry and no `lock`, `fetch`, `update`, or
  `publish`.
- **Concurrency** has workers, channels, mutexes, and bounded parallel maps, but worker ownership by
  lexical scope and cancellation propagation are incomplete.
- **HTTP client** requests have verified TLS, redirects, limits, and deadlines, but no in-flight
  cancellation or connection pooling.
- **Large inputs.** File streaming is proven memory-bounded. `Std.Csv` and `Std.Json` read whole
  documents only, and network, HTTP, and database readers lack the same evidence.
- **Native media** has portable Pudu cores; device adapters exist for macOS only.
- **Versioning.** Until 1.0, a minor version may change the language. Manifests state the versions
  they accept, and development builds all report `0.1.0`.

## Documentation

- [Documentation website](https://website-ivory-one-hyy8j9ljag.vercel.app/)
- [Wiki](https://github.com/chrismichaelps/pudu-lang/wiki): the
  [language reference](https://github.com/chrismichaelps/pudu-lang/wiki/Reference-Index),
  [standard library](https://github.com/chrismichaelps/pudu-lang/wiki/Standard-Library),
  [tooling](https://github.com/chrismichaelps/pudu-lang/wiki/CLI-REPL-And-Documentation), and
  [implementation status](https://github.com/chrismichaelps/pudu-lang/wiki/Implementation-Status)
- [`wiki/`](wiki) in this repository: the engineering specification — grammar, semantics,
  architecture decisions, per-module mirrors, and the [changelog](wiki/CHANGELOG.md)

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md). A public behavior change lands as one unit: specification,
implementation, diagnostics, examples, and tests agree. Before opening a pull request, run the release
gates the way CI does:

```bash
bash test/gates.sh
```

It rebuilds from scratch, so it takes several minutes, and it reports every failing gate rather than
stopping at the first.

## License

Apache License 2.0 with the LLVM exception. See [LICENSE](LICENSE).
