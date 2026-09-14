<p align="center">
  <img src="public/pudu-lang-full-logo.png" alt="Pudu" width="800">
</p>

<p align="center">
  <a href="https://website-ivory-one-hyy8j9ljag.vercel.app/">Website</a> |
  <a href="https://github.com/chrismichaelps/pudu-lang/wiki/Reference-Index">Reference</a> |
  <a href="https://github.com/chrismichaelps/pudu-lang/wiki/Standard-Library">Standard library</a> |
  <a href="examples">Examples</a> |
  <a href="CONTRIBUTING.md">Contributing</a>
</p>

# Pudu

Pudu is a statically typed, expression-oriented language for services, tools, and native
applications. Failure is a value, absence is explicit, and every `match` is exhaustive.

This repository holds the compiler, the standard library, and the tooling: one `pudu` executable
that checks, runs, tests, formats, lints, documents, and bundles programs, and serves editors over
the Language Server Protocol.

```pudu
module Shapes

import Std.Io as Io

type Shape
  = Circle(Float)
  | Rectangle(Float, Float)

fn area(shape: Shape) -> Float {
  match shape {
    case Circle(radius) => 3.14159 * radius * radius
    case Rectangle(width, height) => width * height
  }
}

export fn main() -> Result[(), Str] {
  for shape in [Circle(1.0), Rectangle(3.0, 4.0)] {
    Io.writeLine(show(area(shape))) ?
  }
  Ok(())
}
```

> **Pudu is pre-release (0.1.0).** Programs are interpreted, dependencies are local directories, and
> the language may change before 1.0. Open work is tracked in
> [RELEASE-READINESS.md](wiki/architecture/RELEASE-READINESS.md).

## Building from source

No binary release has been published yet. Building requires GHC 9.10 or later and Cabal 3.12 or
later.

```bash
git clone https://github.com/chrismichaelps/pudu-lang.git
cd pudu-lang
cabal install exe:pudu --installdir="$HOME/.local/bin" --overwrite-policy=always
```

Then create and run a project:

```bash
pudu init hello
cd hello
pudu run src/Main.pudu
pudu test
```

The installed executable carries its standard library. Editor support is `pudu lsp`, with a VS Code
extension in [`editors/vscode`](editors/vscode). macOS and Linux x86-64 are tested; Windows is not.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The engineering specification (grammar, semantics, and
design decisions) lives in [`wiki/`](wiki).

## License

Apache License 2.0 with the LLVM exception. See [LICENSE](LICENSE).
