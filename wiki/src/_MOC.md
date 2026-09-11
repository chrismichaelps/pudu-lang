---
type: moc
tags: [moc, module]
---

# Module Map

- [[Notes Web Application]] — database-backed HTML and JSON application composition.

- [[Runtime Word Kernels]] — native-word reductions over existing containers.
- [[Eval Word Map]] — checked UInt64 map payload reductions for STD.
- [[Runtime Buffer Kernels]] — unboxed contiguous byte buffer operations.
- [[Eval Buffer]] — evaluator adapters for buffer builtins.
- [[Runtime SwissTable Kernels]] — flat hash table with 1-byte control metadata.
- [[Eval SwissTable]] — evaluator adapters for flat map builtins.
- [[Runtime Column Kernels]] — vectorized columnar database storage layouts.
- [[Eval Column]] — evaluator adapters for vectorized columnar operations.

- [[Pudu Cabal Manifest]] — package components and explicit runtime module registration.

- [[src/Pudu/_MOC|Pudu modules]] — validated source, diagnostic, lexical-vocabulary, and strict-cursor foundations.
- [[src/Std/_MOC|Standard library modules]] — mirrored Pudu modules shipped under `Std`.
- [[src/cbits/_MOC|Native boundary modules]] — the libffi bridge and test-only C++ conformance
  surface.
- [[src/website/_MOC|Website modules]] — Pudu SSR, generated API search, views, SEO, tests, and narrow platform adapters.
- [[Website Linux Artifact Workflow]] — short-lived x86-64 Pudu website build for preview deployment.
- [[Musl Runtime Workflow]] — portable x86-64 runtime proof across Alpine and Amazon Linux 2.
- [[Musl Toolchain Image]] · [[Musl Runtime Builder]] — reproducible local musl construction.

- [[Runtime Collection Kernels]] — pure internal bulk construction and enumeration kernels.

## Depth Baseline

| Status | Count | Modules |
| --- | ---: | --- |
| DEEP | 3 | [[Lexer Cursor]], [[Parser State]], [[Parser Expression]] |
| MEDIUM | 17 | [[Source]], [[Diagnostic Model]], [[Token]], [[Lexer Facade]], [[Trivia Scanner]], [[Identifier Scanner]], [[Number Scanner]], [[Symbol Scanner]], [[Quoted Scanner]], [[Syntax]], [[Syntax Located]], [[Syntax Name]], [[Syntax Tree]], [[Parser Name]], [[Parser Type]], [[Parser Import]], [[Parser Binding]] |

## Referenced by

[[00-INDEX]] · [[grammar/haskell]]
