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
- [[architecture/PERFORMANCE|Performance Constitution]] — compiler throughput, low-level IR, optimization barriers, and benchmarks.

## Governance Dashboard

- **Maturity:** EXPLORING — fewer than 20k lines, pre-release, one active implementation team.
- **Depth distribution:** no implementation modules yet; measured as slices land.
- **Seam health:** [[Native Toolchain]] is EXPLORATORY and HEALTHY by design specification.
- **Lifecycle:** 1 EXPLORATORY seam; no collapse-eligible seams.
- **Chain risk:** none; internal compiler phases remain within bounded subsystems.
- **Momentum:** depth → · coupling → · debt → (baseline).
- **Deepening policy:** SKIP speculative abstraction; deepen only core-path boundaries.

## Referenced by

[[00-INDEX]] · [[architecture/OVERVIEW]] · [[Tooling]]
