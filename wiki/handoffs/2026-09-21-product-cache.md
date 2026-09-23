---
type: handoff
status: COMPLETE
date: 2026-09-21
issue: 272
tags: [handoff, compiler, cache, incremental, startup, performance]
aliases: [2026-09-21-product-cache]
---

# Product Cache Handoff

## Objective

Resolve issues #272 and #273 by keeping each unchanged module's parsed and checked products across
compiler runs, keyed so that a lookup can only ever find the product of exactly this input, and by
reading stored products lazily so a run pays only for what it reaches.

## Ownership and role transitions

1. **Compiler Engineer:** [[Compiler Cache]], [[Cache Persist]], [[Compiler Program]], [[Source]],
   [[Syntax Tree]] stored forms, and the CLI's use of the cache.
2. **Test Engineer:** `CacheSpec.hs` and the fixture-wide equivalence sweep.
3. **Forensic Guardian:** reconciles source, mirrors, MOC, changelog, measurement, and this handoff.
   No separate review agent is used at the repository owner's direction.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close it without a pull request.

## Contract

- Frontend products are keyed by source text; checked products by source text and the program's
  interface keys (every module's name and position-free interface fingerprint); both under a
  directory named by the compiler's version and executable identity.
- Only products without diagnostics are stored; every diagnostic is produced fresh.
- Content decides validity, never timestamps. Entries carry a digest, are renamed into place, and
  are a miss when they do not verify; failed writes remove their temporary file.
- The cache is bounded (least recently read pruned past 4096 entries) and optional
  (`PUDU_CACHE=off`); compiling never depends on it.
- A stored module's declarations and function bodies are read on first use; the compile context is
  built only if some module must be checked.
- Tooling that needs tokens, resolutions, types, or documentation compiles without the cache.

## Measurement

Optimized GHC 9.10.3 build, same macOS host. Before is `0a93f093`; "No cache" includes #268.

| Full-stack example | Before | No cache | Warm cache |
|---|---:|---:|---:|
| `check`, median | 0.745s | 0.302s | 0.025s |
| `check`, heap allocation | 1.92GB | 492MB | 24MB |
| `check`, maximum residency | 72.8MB | 44.8MB | 4.3MB |
| process start to `listening`, best | 745.8ms | 355.1ms | 70.0ms |
| after editing one function body, `check` | — | — | 0.050s, 61MB |

The first run that fills the cache costs 0.46s. The whole cache for the example is 1.7MB in 126
entries. A minimal one-module program allocates 2.2MB, the runtime's own floor.

## Completion evidence

- Focused tests: cache off, storing, and reading runs agree on diagnostics, link order, and run
  result for cycles, ambiguity, alias fields, and the whole standard library; a same-length,
  same-timestamp edit is seen; a signature change re-checks its importer and matches an uncached
  compile; damaged and truncated entries fall back and are replaced.
- A sweep of every fixture under `test-fixtures` compares `check` and `run` with the cache off,
  storing, and reading: identical output and status for all 352 programs except two whose uncached
  output differs run to run (audio sample counts, server log timing).
- The optimized complete suite and the repository gate script pass.

## Exact next action

None for #272 and #273.

## Referenced by

[[handoffs/_MOC]] · [[Compiler Cache]] · [[Cache Persist]]
