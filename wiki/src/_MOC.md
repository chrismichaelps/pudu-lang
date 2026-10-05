---
type: moc
tags: [moc, module]
---

# Module Map

- [[Eval Binding Flow Tests]] — lexical order, branches, transfers and pure loop semantics.

- [[Type Implementation Proof Spec]] — concrete conditional capability evidence.

- [[Derive Record Kernel Spec]] — generated method execution and refusal.

- [[Generated Identity Spec]] — generated origins and complete fact identity.

- [[Compiler Benchmark]] · [[Benchmark Guide]] — reproducible cold/warm compiler latency.

- [[Dependency Layer Report]] · [[Dependency Layer Model]] · [[Dependency Layer View]] · [[Dependency Layer Tests]] — offline source layers, import cycles and exclusive measured resource attribution.

- [[src/test-fixtures/stdlib/UsesMultiMapPersistent]] · [[src/test-fixtures/stdlib/RejectsMultiMapOverflow]] · [[src/test-fixtures/stdlib/RejectsMultiMapUnordered]] — MultiMap snapshots, duplicates, ordering, folding, and refusal regressions.

- [[Uses Yaml Block]] — full scalar trees, sibling retention, physical content and typed indentation refusal.

- [[src/test-fixtures/listeneridentity/Main]] · [[src/test-fixtures/listeneridentity/Reverse]] · [[src/test-fixtures/listeneridentity/RejectsWrongListener]] · [[src/test-fixtures/listeneridentity/PackageLog/Configuration]] · [[src/test-fixtures/listeneridentity/PackageLog/Sink]] · [[src/test-fixtures/listeneridentity/ZServer]] — actual HTTP server with conflicting package aliases, two traversal orders, and refusal.

- [[src/test-fixtures/exhaustnamespace/UsesJsonCoverage]] · [[src/test-fixtures/exhaustnamespace/UsesJsonCoverageReversed]] · [[src/test-fixtures/exhaustnamespace/RejectsJsonCoverage]] · [[src/test-fixtures/exhaustnamespace/R/Value]] · [[src/test-fixtures/exhaustnamespace/R/Kinds]] · [[src/test-fixtures/exhaustnamespace/R/ZJson]] — module-owned nested constructor coverage and refusal.

- [[src/test-fixtures/stdlib/UsesYamlQuoted]] — quoted escape values, flow delimiters, and typed malformed-text refusal.

- [[src/test-fixtures/stdlib/RejectsOptionUnwrapMethodImported]] · [[src/test-fixtures/stdlib/RejectsOptionUnwrapMethodUnimported]] · [[src/test-fixtures/stdlib/UsesOptionUnwrapQualified]] — exact Option.unwrapOr method refusals and qualified success.

- [[src/test-fixtures/latealias/Main]] · [[src/test-fixtures/latealias/RejectsWrongCallback]] · [[src/test-fixtures/latealias/Lib/Sink]] — imported late callback aliases and wrong callback refusal.

- [[Uses Decimal Dispatch]] — Decimal trait receiver, generic, and qualified calls.

- [[Uses Yaml Compact Sequence]] — exact nested compact-sequence trees and depth refusal.

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
- [[Eval Json]] — native JSON decoder and encoder behind `Std.Json`.
- [[Eval Xml]] — native XML reader behind `Std.Xml`.
- [[Runtime Column Kernels]] — vectorized columnar database storage layouts.
- [[Eval Column]] — evaluator adapters for vectorized columnar operations.

- [[Std Mutation Harness]] — internal operator-mutation audit of Std against its fixtures.
- [[Pudu Cabal Manifest]] — package components and explicit runtime module registration.
- [[VS Code Grammar]] — the editor extension's TextMate grammar, interpolations included.
- [[Pudu Cabal Project]] · [[Pudu Test Cabal Manifest]] — self-contained compiler packaging and the
  repository-only regression package that preserves `cabal test all`.
- [[Pudu Package Project]] · [[Package Binary]] — the release build plan (split sections) and the
  stripped, reproducible archive it becomes.
- [[Refresh Pudu Installation]] — PATH-aware installed-compiler replacement and behavior proof.
- [[Bundle End-to-End Gate]] — copied-bundle execution, cache isolation, and build refusal coverage.
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
- [[Atomic Permission Gate]] — real byte/text writes under child-local umasks, existing modes,
  symlink replacement, refusal output, private scratch files, and temporary-file cleanup.
- [[Uses Crypto All]] — digests against independent vectors, RFC 4231 keyed digests, and sealing refusals.

- [[src/Pudu/_MOC|Pudu modules]] — validated source, diagnostic, lexical-vocabulary, and strict-cursor foundations.
- [[src/Std/_MOC|Standard library modules]] — mirrored Pudu modules shipped under `Std`.
- [[src/cbits/_MOC|Native boundary modules]] — the libffi bridge, private desktop target adapter,
  and test-only C++ conformance surface.
- [[Package registry end-to-end suite]] — local GitHub, registry, CLI, and website snapshot integration flow.
- [[src/website/_MOC|Website modules]] — Pudu SSR, generated API search, views, SEO, tests, and Pudu-native deployment entries.
- [[Website Linux Artifact Workflow]] — short-lived x86-64 Pudu website build for preview deployment.
- [[Musl Runtime Workflow]] — portable x86-64 runtime proof across Alpine and Amazon Linux 2023.
- [[Public HTTP Integration Workflow]] — weekly real-network checks: public HTTP endpoints and the live package index.
- [[Musl Toolchain Image]] · [[Musl Runtime Builder]] — reproducible local musl construction.

- [[Runtime Series Map]] · [[Runtime Series Map Tests]] — proven persistent
  constant-payload numeric series with arbitrary sparse overrides.

- [[Runtime Collection Kernels]] — pure internal bulk construction and enumeration kernels.

## Depth Baseline

| Status | Count | Modules |
| --- | ---: | --- |
| DEEP | 3 | [[Lexer Cursor]], [[Parser State]], [[Parser Expression]] |
| MEDIUM | 17 | [[Source]], [[Diagnostic Model]], [[Token]], [[Lexer Facade]], [[Trivia Scanner]], [[Identifier Scanner]], [[Number Scanner]], [[Symbol Scanner]], [[Quoted Scanner]], [[Syntax]], [[Syntax Located]], [[Syntax Name]], [[Syntax Tree]], [[Parser Name]], [[Parser Type]], [[Parser Import]], [[Parser Binding]] |

## Runtime benchmark fixtures

- [[HTTP Benchmark Service]] — real three-route service with an explicit connection budget.

## Referenced by

[[00-INDEX]] · [[grammar/haskell]]

- [[Eval Foreign Binding]] — native metadata extracted unchanged from runtime values.

- [[Eval Loop Kernel]] — complete pure regions, ordered indexing and closed module functions.
- [[Eval Loop Step]] · [[Eval Loop Step Tests]] — shared region execution without boxed intermediate result wrappers.
- [[Eval Value]] · [[Eval MultiMap]] · [[Eval Operator Access]] · [[Eval Data Tests]] — compact persistent occurrence entries, exact integer index bounds and runtime compatibility evidence.

- [[UsesMultiMapNumeric]] — numeric index and native-loop semantic compatibility.

- [[RejectsMultiMapLoopOverflow]] — native MultiMap loop diagnostic compatibility.

- [[RejectsMultiMapStepLimit]] — native MultiMap loop diagnostic compatibility.

- [[Eval Call Argument]] — argument values and receiver lending places.
- [[Eval Call Needs]] — evaluator callbacks shared by call dispatch and argument discovery.
