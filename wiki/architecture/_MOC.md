---
type: moc
maturity: EXPLORING
tags: [moc, architecture]
---

# Architecture Map

## Purpose

Pudu is a statically typed native systems language for developers who need predictable performance and explicit control without unchecked memory access in ordinary code.

## Pages

- [[architecture/LANGUAGE|Architecture Language]] — canonical FMCF vocabulary.
- [[architecture/OVERVIEW|Compiler Architecture]] — phases, dependency direction, and delivery sequence.
- [[architecture/SEMANTICS|Pudu Semantic System]] — normative static, dynamic, ownership, failure, and concurrency meaning.
- [[architecture/FMCF Workflow|FMCF Workflow]] — repository-specific operating contract.
- [[architecture/DELIVERY|Engineering Delivery]] — branches, issues, agents, reviews, gates, and releases.
- [[architecture/MACROS|Macro Design]] — the macro form as hygienic typed syntax transformers, and what was rejected.
- [[architecture/STDLIB|Standard Library Design]] — the `Std` namespace, the shipped modules, the import DX, and what production-ready is required to mean.
- [[architecture/PATTERNS]] — every design pattern written in Pudu and run: which dissolve, which are ordinary generics, and the one feature that was missing.
- [[architecture/PERFORMANCE|Performance Constitution]] — compiler throughput, low-level IR, optimization barriers, and benchmarks.
- [[architecture/PACKAGES|Package System]] — manifests, lockfiles, resolution, cache security, and registry protocol.

- [[architecture/FFI-SELF-HOSTING]] — remaining FFI ownership contracts and concrete self-hosting stages.

## Governance Dashboard

- **Maturity:** EXPLORING — fewer than 20k lines, pre-release, one active implementation team.
- **Depth distribution:** 3 MEDIUM implementation modules ([[Source]], [[Diagnostic Model]], [[Token]]); deeper compiler slices remain planned.
- **Seam health:** [[Native Toolchain]] is EXPLORATORY and HEALTHY by design specification.
- **Lifecycle:** 1 EXPLORATORY seam; no collapse-eligible seams.
- **Chain risk:** none; internal compiler phases remain within bounded subsystems.
- **Momentum:** depth ↑ · coupling → · debt → (closed lexical vocabulary follows source and diagnostics).
- **Deepening policy:** SKIP speculative abstraction; deepen only core-path boundaries.

## Referenced by

[[00-INDEX]] · [[architecture/OVERVIEW]] · [[Tooling]]
