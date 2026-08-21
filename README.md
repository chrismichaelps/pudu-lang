# Pudu

Pudu is a statically typed native systems language for predictable performance and explicit control without unchecked memory access in ordinary code.

The repository is governed wiki-first. Start at [`wiki/00-INDEX.md`](wiki/00-INDEX.md); the normative static and dynamic rules are in [`wiki/architecture/SEMANTICS.md`](wiki/architecture/SEMANTICS.md), and the engineering workflow is in [`wiki/architecture/DELIVERY.md`](wiki/architecture/DELIVERY.md).

The compiler is pre-release. Syntax or semantics not represented in the versioned vault are not implementation promises.

The release toolchain is locked in [`wiki/grammar/haskell.md`](wiki/grammar/haskell.md). The current source-location foundation builds and tests with:

```sh
cabal build all
cabal test all --test-show-details=direct
```

Release validation uses `--enable-optimization=2`; normal local work uses the unoptimized project profile for fast feedback.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) before proposing language or compiler changes.
