<p align="center">
  <img src="public/pudu-lang-full-logo.png" alt="Pudu" width="800">
</p>

# Pudu

Pudu is a statically typed, expression-oriented language. Effects return `Result` values, absence
is explicit, pattern matching is exhaustive, and unsafe code sits inside named capability regions.
The standard library is ordinary Pudu source checked by the same compiler.

Pudu is pre-release. The compiler checks, interprets, formats, documents, serves editor requests,
and runs an interactive session. A project may depend on other directories of Pudu code by path;
there is no registry, and nothing reaches the network. Native code generation and a stable 1.0
compatibility promise are not implemented yet.

Start with the [wiki](https://github.com/chrismichaelps/pudu-lang/wiki). The quickest references are
[language](https://github.com/chrismichaelps/pudu-lang/wiki/Reference-Index),
[standard library](https://github.com/chrismichaelps/pudu-lang/wiki/Standard-Library),
[tooling](https://github.com/chrismichaelps/pudu-lang/wiki/CLI-REPL-And-Documentation), and
[status](https://github.com/chrismichaelps/pudu-lang/wiki/Implementation-Status). The versioned
[`wiki/`](wiki) directory remains the engineering specification for grammar, semantics,
architecture, module mirrors, and delivery history.

## Build

Pudu requires GHC 9.10 or later and Cabal 3.12 or later. CI uses GHC 9.14.1.

```bash
cabal build all
cabal test all --test-show-details=direct
cabal run pudu -- check path/to/Main.pudu
```

## Install

```bash
export PATH="$HOME/.local/bin:$PATH"
scripts/refresh-install.sh
```

The script builds, installs to `$HOME/.local/bin` (pass another directory as its
argument), and then proves that exact file with `pudu check`, a REPL probe, and a
real LSP session. It also lists every `pudu` on `PATH` and stops if an older copy
comes first, because a second copy is what makes a fix land in the tree and never
reach the editor — every development build reports the same version, so nothing
else notices.

Run it again after any change to the compiler, and restart the editor's language
server so it picks up the new executable.

Development builds currently share version `0.1.0.0`, so the checks above prove the installed
binary by behavior instead of trusting the version string.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md). Public behavior changes as one unit: specification,
implementation, diagnostics, examples, and tests must agree.

## License

Apache License 2.0 with the LLVM exception. See [LICENSE](LICENSE).
