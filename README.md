# Pudu

A statically typed, expression-oriented language. Effects return results,
not exceptions. Pattern matching is exhaustive. Unsafe is an audited region
with named capabilities, not an escape hatch. The standard library is
ordinary Pudu source checked by the same compiler.

Pre-release. The compiler type-checks and interprets; native codegen and
package management are not here yet.

**[Wiki](https://github.com/chrismichaelps/pudu-lang/wiki)** · [Reference](https://github.com/chrismichaelps/pudu-lang/wiki/Reference-Index) · [Std](https://github.com/chrismichaelps/pudu-lang/wiki/Standard-Library) · [Status](https://github.com/chrismichaelps/pudu-lang/wiki/Implementation-Status)

## Build

GHC ≥ 9.10, Cabal ≥ 3.12. CI uses 9.14.1.

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

Development builds share version `0.1.0.0`; the behavioral checks above
confirm the installed binary is current.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md). The versioned [`wiki/`](wiki) directory
is the engineering specification — grammar, semantics, and architectural
decisions live there with the code they govern.

## License

Apache 2.0 with the LLVM exception — see [LICENSE](LICENSE).
