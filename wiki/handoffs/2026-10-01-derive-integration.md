---
type: handoff
tags: [handoff, derive, compiler, stdlib]
---

# Complete Derive integration

## Authorization and state

The user requests complete [[Derive Design]] implementation, continuing the
uncommitted frontend work on `feature/430-derive-frontend`. Preserve every pending
change. The latest instruction permits focused commits as soon as tests pass, while prohibiting PRs or review requests.
The preceding MultiMap repair is delivered separately as 71fb2adf.

## Roles and ownership

Language Architect resolves the integration contracts in [[Derive Design]] before
implementation. Architect → Frontend Engineer: parser/AST/traversal correctness and
frontend tests, preserving the existing issue #430 work. Architect → Semantic
Engineer: generic derive validation, bound proof, metadata typing, static trait
selection, graph phase integration and cache invalidation. Architect → Expansion
Engineer: new residualization modules, canonical derive catalog, field/variant
metadata elimination and generated impl construction. Architect → Stdlib Engineer:
ordinary Meta facade, seven library derives and their required ordinary traits and
container instances. Architect → Tooling Engineer: span provenance, CLI expansion,
benchmarks, integration tests and coordinated registration/docs.

Each implementation worker reads complete mirrored pages before editing and writes
complete mirrors with resolved Grill Logs before creating a module. Workers are
not alone and preserve unrelated edits. Cabal, MOCs, this handoff and changelog are
owned by the integration owner; workers report their required additions.

## Dependency layers

```mermaid
flowchart TD
  Syntax[Attributes and derive syntax] --> Identity[Generated identity and provenance]
  Syntax --> Catalog[Canonical shape and derive catalog]
  Catalog --> Check[Once generic body checking and field bounds]
  Check --> Expand[Bounded metadata residualization]
  Identity --> Expand
  Expand --> Heads[Ordinary impl graph interfaces]
  Heads --> Ordinary[Existing checker and evaluators]
  Ordinary --> Library[Std derives and container instances]
  Expand --> CLI[Expansion output]
  Library --> Gates[Output, refusal, cache, native and performance gates]
```

## Required evidence

All shipped derives cover records, sums where applicable, generics, recursive
values and attributes. Definition errors appear once even without a request.
Missing field bounds point at the field with the request note. No Meta call or
compile-time loop reaches runtime. Imports, aliases, coherence, generic nested
bounds, budgets, distinct generated literal identities, cache invalidation and
source provenance receive focused regression checks. Derived JSON encoding is
compared to handwritten encoding with the same data and evaluation modes.

## Exact next action

Harden generic checking: validate every derive against its canonical trait
contract, check loop sources, and preserve scoped bounds and obligations.
Resolved reflection boundaries, rigid scope reuse, bounded attribute recovery
and structural duplicate detection pass the full optimized suite (511
properties, `-Werror`, 2026-10-02). Instantiation remains the next dependency layer.

## Referenced by

[[handoffs/_MOC]] · [[Derive Design]] · [[Engineering Delivery]]

## Solo hardening continuation

2026-10-02: all implementation and validation are owned by one integration
engineer. No sub-agents run. Authoritative ticket scopes are #432 resolution,
#433 generic checking, #431 complete integration and #430 frontend; #434 tracks
Meta groundwork. Preserve unrelated desktop metadata files and existing user
changes. Commit each validated improvement without opening a PR.
