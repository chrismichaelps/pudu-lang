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

## License

Pudu is licensed under the **Apache License 2.0 with the LLVM exception**
([`LICENSE`](LICENSE)) — the licence LLVM, Swift, and Clang use, and for the
reason they use it.

Two things about a language make that the right choice rather than a plain
permissive licence:

- **What the compiler embeds in your program is yours to ship.** The standard
  library is written in Pudu and ends up inside what you build. Under Apache 2.0
  alone, every binary compiled with Pudu would carry Apache's attribution
  requirement for those embedded parts. The exception removes that: you
  redistribute what you build without attributing Pudu in it.
- **Contributions carry a patent grant.** Apache 2.0 grants patent rights
  explicitly, which MIT and BSD do not. For a language that may take
  contributions from people whose employers hold patents, that grant is what
  makes the code safe to depend on.

The exception's second paragraph also resolves Apache 2.0's incompatibility with
GPLv2, so a GPLv2 program may link what Pudu produces. That is the problem Rust
solves by dual-licensing under MIT *or* Apache 2.0; the LLVM exception solves it
directly, without a second licence to reason about.

Using the language, and distributing what you write in it, requires nothing of
you. The licence governs the compiler and the standard library themselves —
contributing to them, forking them, or redistributing them.

