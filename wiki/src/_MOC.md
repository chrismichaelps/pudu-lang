---
type: moc
tags: [moc, module]
---

# Module Map

- [[Examples]] — human-run programs and the boundary between demonstrations and release evidence.
- [[Media Studio Example]] — real-window integration of exact video timing, generated Canvas frames,
  bounded audio graph rendering, and WAV delivery.
- [[Media Studio Configuration]] · [[Media Studio Example Configuration]] — checked nested workload
  configuration and its representative device-run preset.
- [[Media Studio Configuration Checks]] — headless success and refusal coverage for the workload.
- [[Notes Web Application]] — database-backed HTML and JSON application composition.

- [[Runtime Word Kernels]] — native-word reductions over existing containers.
- [[Eval Word Map]] — checked UInt64 map payload reductions for STD.
- [[Runtime Buffer Kernels]] — unboxed contiguous byte buffer operations.
- [[Eval Buffer]] — evaluator adapters for buffer builtins.
- [[Runtime SwissTable Kernels]] — flat hash table with 1-byte control metadata.
- [[Eval SwissTable]] — evaluator adapters for flat map builtins.
- [[Eval Csv]] — native separated-record scan behind `Std.Csv`.
- [[Runtime Column Kernels]] — vectorized columnar database storage layouts.
- [[Eval Column]] — evaluator adapters for vectorized columnar operations.

- [[Pudu Cabal Manifest]] — package components and explicit runtime module registration.
- [[Pudu Cabal Project]] · [[Pudu Test Cabal Manifest]] — self-contained compiler packaging and the
  repository-only regression package that preserves `cabal test all`.
- [[Refresh Pudu Installation]] — PATH-aware installed-compiler replacement and behavior proof.
- [[Pudu Test Cabal Manifest]] · [[Pudu Cabal Project]] — repository test ownership separated from
  the installable compiler archive while preserving the full Cabal gate.
- [[Service Evaluation Spec]] — exact-count application, database, HTML, and UI fixture contracts.
- [[Runtime Evaluation Spec]] — exact-count language, runtime, concurrency, filesystem, process, and cryptography fixture contracts.
- [[Uses Ui Canvas]] — exact-pixel and typed-refusal coverage for native software rendering.
- [[Uses Ui Layout]] — exact-frame, accessibility, and repaint-equality coverage for layout.
- [[Uses Ui Screen]] — input routing, focus, and incremental frames equal to fresh ones.
- [[Uses Ui Desktop]] — safe window plans and the typed desktop-session boundary.
- [[Launch Ui Desktop]] — explicit real-window launch, presentation, event-pump, and close evidence.
- [[Uses Ui Text]] — exact measures, wrapping edges, and glyph pixels for bitmap text.
- [[Uses Audio]] — exact samples, time, gain, mixing, slicing, and WAV bytes and refusals.
- [[Uses Audio Graph]] — exact waveforms, ramps, and mixes, with split renders equal to whole ones.
- [[Uses Video]] — exact NTSC timing over an hour, cross-scale arithmetic, and track ordering refusals.
- [[Uses Fs]] — atomic replacement, temporary names, permissions, containment, and non-following removal.
- [[Uses Crypto All]] — digests against independent vectors, RFC 4231 keyed digests, and sealing refusals.

- [[src/Pudu/_MOC|Pudu modules]] — validated source, diagnostic, lexical-vocabulary, and strict-cursor foundations.
- [[src/Std/_MOC|Standard library modules]] — mirrored Pudu modules shipped under `Std`.
- [[src/cbits/_MOC|Native boundary modules]] — the libffi bridge, private desktop target adapter,
  and test-only C++ conformance surface.
- [[src/website/_MOC|Website modules]] — Pudu SSR, generated API search, views, SEO, tests, and Pudu-native deployment entries.
- [[Website Linux Artifact Workflow]] — short-lived x86-64 Pudu website build for preview deployment.
- [[Musl Runtime Workflow]] — portable x86-64 runtime proof across Alpine and Amazon Linux 2023.
- [[Musl Toolchain Image]] · [[Musl Runtime Builder]] — reproducible local musl construction.

- [[Runtime Collection Kernels]] — pure internal bulk construction and enumeration kernels.

## Depth Baseline

| Status | Count | Modules |
| --- | ---: | --- |
| DEEP | 3 | [[Lexer Cursor]], [[Parser State]], [[Parser Expression]] |
| MEDIUM | 17 | [[Source]], [[Diagnostic Model]], [[Token]], [[Lexer Facade]], [[Trivia Scanner]], [[Identifier Scanner]], [[Number Scanner]], [[Symbol Scanner]], [[Quoted Scanner]], [[Syntax]], [[Syntax Located]], [[Syntax Name]], [[Syntax Tree]], [[Parser Name]], [[Parser Type]], [[Parser Import]], [[Parser Binding]] |

## Referenced by

[[00-INDEX]] · [[grammar/haskell]]
