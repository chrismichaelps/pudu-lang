---
type: moc
maturity: EXPLORING
tags: [moc, architecture]
---

# Architecture Map

- [[Native Unsigned Integers]] — full unsigned domains through 64 bits (#500).

- [[Native Signed Integers]] — canonical fixed signed-width admission and exact semantics (#497).

## Purpose

Pudu is a statically typed native systems language for developers who need predictable performance and explicit control without unchecked memory access in ordinary code.

## Pages

- [[ADR-0025-if-without-else-unit-results]] — no-else unit conformance across execution and compilation paths.

- [[Application Maturity]] — database correctness, measured throughput and application dependency layers.

- [[Application Dependency Layers]] — enforced application source graph and explicit architectural direction.

- [[architecture/LANGUAGE|Architecture Language]] — canonical FMCF vocabulary.
- [[architecture/OVERVIEW|Compiler Architecture]] — phases, dependency direction, and delivery sequence.
- [[architecture/SEMANTICS|Pudu Semantic System]] — normative static, dynamic, ownership, failure, and concurrency meaning.
- [[architecture/FMCF Workflow|FMCF Workflow]] — repository-specific operating contract.
- [[architecture/DELIVERY|Engineering Delivery]] — branches, issues, agents, reviews, gates, and releases.
- [[architecture/MACROS|Macro Design]] — the macro form as hygienic typed syntax transformers, and what was rejected.
- [[architecture/DERIVES|Derive Design]] — code written once for every type that asks, from compile-time reflection that leaves the program.
- [[architecture/COMPILED-EVALUATION|Compiled Evaluation]] — compiling checked functions to slot-resolved closures, with the tree walker as oracle.
- [[architecture/STDLIB|Standard Library Design]] — the `Std` namespace, the shipped modules, the import DX, and what production-ready is required to mean.
- [[architecture/RELEASE-READINESS|First Release Readiness]] — evidence-based v1 blockers, completed rows, and work order.
- [[architecture/NATIVE-UI|Native Application UI]] — Pudu-native software rendering, audio, video, and explicit platform boundaries.
- [[architecture/DESKTOP-CONFORMANCE|Desktop Capability Conformance]] — behavioral desktop coverage,
  executable evidence, and explicit UI/audio/video gaps without copying AppKit's class surface.
- [[architecture/PATTERNS]] — every design pattern written in Pudu and run: which dissolve, which are ordinary generics, and the one feature that was missing.
- [[architecture/PERFORMANCE|Performance Constitution]] — compiler throughput, low-level IR, optimization barriers, and benchmarks.
- [[architecture/PACKAGES|Package System]] — manifests, lockfiles, resolution, cache security, and registry protocol.
- [[architecture/WEBSITE|Pudu Website Architecture]] — generated API data, Pudu SSR, static canonical pages, dynamic search, SEO, and the Vercel boundary.
- [[architecture/DEPLOYMENT-TARGETS|Deployment Targets]] — how a bundle's linking decides where it runs, the musl runtime, building for a platform from a machine that is not it, and what a bundle needs once it starts.

- [[architecture/FFI-SELF-HOSTING]] — remaining FFI ownership contracts and concrete self-hosting stages.

- [[architecture/BACKEND-SPECIALIZATION]] — evidence-driven layouts, kernels and backend optimization roadmap.

## Governance Dashboard

- **Maturity:** EXPLORING — fewer than 20k lines, pre-release, one active implementation team.
- **Depth distribution:** 3 MEDIUM implementation modules ([[Source]], [[Diagnostic Model]], [[Token]]); deeper compiler slices remain planned.
- **Seam health:** [[Native Toolchain]] is EXPLORATORY and HEALTHY by design specification.
- **Lifecycle:** 1 EXPLORATORY seam; no collapse-eligible seams.
- **Chain risk:** none; internal compiler phases remain within bounded subsystems.
- **Momentum:** depth ↑ · coupling → · debt → (closed lexical vocabulary follows source and diagnostics).
- **Deepening policy:** SKIP speculative abstraction; deepen only core-path boundaries.
- [[Native Trait Methods]] — static dispatch of implementation members and defaults (#551).
- [[Native Generics]] — one copy per type list (#552).
- [[Native Closures]] — function values as boxes (#555).
- [[Native Arrays]] — arrays as owned growable buffers (#556).
- [[Native Maps and Sets]] — maps and sets over shared persistent trees (#561).
- [[Native Range Values]] — ranges as values (#564).

## Referenced by

[[00-INDEX]] · [[architecture/OVERVIEW]] · [[Tooling]]

- [[Application Deployment Contract]] — process and platform adapter boundaries, security and scaling obligations.

- [[Scoped Import Design]] — build-time lexical import proposal and resolved qualifier prerequisite.

- [[Native Emission Coverage]] — implemented native surfaces and remaining completion obligations.

- [[Exact Native Integer Carriers]] — preserve accepted deferred magnitudes without lossy C narrowing (#498).

- [[Native Execution Frames]] — explicit continuations and frame ownership for recursion-depth parity (#499).

- [[Native Wide Integers]] — portable 128-bit arithmetic prerequisite.

- [[Native Wide Operations]] — resolved typed 128-bit operation contract (#503).

- [[Native Wide Runtime Integration]] — full-width printing/status and actual dependencies (#504).

- [[Native Closed Pipe Semantics]] — P1 native process/output parity (#505).

- [[Native Wide Frame Bridge]] — exact 128-bit execution-frame integration (#506).

- [[Native Wide Source Admission]] — canonical Int128/UInt128 source conformance (#507).

- [[Native Floating Point]] — exact width, rounding and decimal-output delivery.

- [[Native Binary64 Formatter]] — exact locked GHC decimal text and retained notices (#509).

- [[Native Folded Constants]] — immutable compiler-folded products in native lowering (#543).

- [[Native Shared References]] — borrows as value identity in native code (#544).

- [[Native Output Results]] — typed output outcomes and exact handle failures (#566).

- [[Native Expression Bodies]] — named expression-body lowering (#567).

- [[Native Named Callable Dispatch]] — direct named targets preserve depth and invocation provenance (#568).

- [[Native Output Callable Values]] — builtin identity, depth and output parity (#569).

- [[Native Diagnostic Ownership]] — surviving payload cleanup at fatal exit (#570).

- [[Native Rendering Callables]] — typed display/show values.
- [[Native Collection Callables]] — charFromCode, bytesOf, mapOf and setOf values; refusals at the caller.
- [[Native Stopping Builtins]] — panic and untyped convertInteger, direct and as values.
- [[Native Place Assignment]] — field and element paths, root-span failures.
- [[Native Method Values]] — receiver-bound built-in methods, failures at the caller.
- [[Native Default Parameters]] — a supplied-count parameter and a default prologue.
