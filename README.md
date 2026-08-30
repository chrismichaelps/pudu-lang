# Pudu

Pudu is a statically typed, expression-oriented language. Effects return `Result` values, absence
is explicit, pattern matching is exhaustive, and unsafe code sits inside named capability regions.
The standard library is ordinary Pudu source checked by the same compiler.

Pudu is pre-release. The compiler checks, interprets, formats, documents, serves editor requests,
and runs an interactive session. Native code generation, package management, and a stable 1.0
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
mkdir -p "$HOME/.local/bin"
cabal install exe:pudu --installdir="$HOME/.local/bin" --overwrite-policy=always
export PATH="$HOME/.local/bin:$PATH"
hash -r
test "$(command -v pudu)" = "$HOME/.local/bin/pudu"
pudu check test-fixtures/tooling/RecentLanguage.pudu
node test/lsp-session.mjs "$(command -v pudu)"
```

Development builds currently share version `0.1.0.0`, so the checks above prove the installed
binary by behavior instead of trusting the version string.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md). Public behavior changes as one unit: specification,
implementation, diagnostics, examples, and tests must agree.

## License

Apache License 2.0 with the LLVM exception. See [LICENSE](LICENSE).
