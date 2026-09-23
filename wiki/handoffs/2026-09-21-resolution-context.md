---
type: handoff
status: COMPLETE
date: 2026-09-21
issue: 267
tags: [handoff, compiler, modules, startup, performance]
aliases: [2026-09-21-resolution-context]
---

# Resolution Context Handoff

## Objective

Resolve issue #267 by discovering project and standard-library roots once per compiler invocation,
reusing the same manifest snapshot for language diagnostics, and avoiding repeated failed-module
probes without allowing resolution state to become stale across invocations.

## Ownership and role transitions

1. **Tooling Architect:** [[Compiler Program]], [[Compiler Library]], and [[Compiler Manifest]] settle
   snapshot lifetime, ordered precedence, failure memoization, and measurement semantics.
2. **Compiler Engineer:** owns `Program.hs`, `Library.hs`, and `Manifest.hs`.
3. **Test Engineer:** owns `GraphSpec.hs` and `StdlibSpec.hs`, including filesystem-change and
   deterministic operation-count evidence.
4. **Forensic Guardian:** reconciles source, mirrors, MOC, changelog, measurement, and this handoff
   after gates. No separate review agent is used at the repository owner's direction.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close it without a pull request. Production validation and source/vault parity
remain required.

## Contract

- One compile invocation reads at most one governing manifest, walks its ancestor candidates once,
  and probes each distinct project or library root once.
- Candidate deduplication preserves the first root's precedence.
- Manifest language diagnostics and dependency roots derive from the same retained bytes.
- A missing module is probed once per requested name, but every importing span receives its own
  diagnostic.
- Resolution context is discarded after the call. Every independent invocation observes current
  manifest contents, environment, executable layout, dependency directories, and module files.
- Existing public compiler entry points and diagnostic/runtime behavior remain compatible.

## Exact next action

Run the complete repository gates, reconcile any failures without weakening them, then commit
directly to `dev`, post the commit on issue #267, close it, and continue to the next oldest issue.

## Measurement

Measured with the repository's optimized GHC 9.10.3 build on the same macOS host. The full-stack
example resolves 63 modules: seven project modules and 56 standard-library modules.

| Measure | Before | After |
|---|---:|---:|
| manifest ancestor existence checks | 378 | 6 |
| standard-library root existence probes | 1,176 | 20 |
| executable ancestor walks | 56 | 1 |
| best of five, process start to `listening` | 761.0ms | 748.2ms |
| best of five, process start to loopback socket ready | 761.7ms | 748.9ms |
| `check examples/fullstack/Main.pudu` heap allocation | 1,949,389,304 bytes | 1,918,713,536 bytes |

The wall-clock samples include process startup, compilation, application initialization, in-memory
database migration/seed, and binding. Socket-ready is a successful loopback TCP connection after the
application's listening announcement; it is not request latency or network TTFB. Operation counts
come from the resolution phases rather than timing assertions and therefore do not depend on host
noise.

## Completion evidence

- Focused snapshot tests cover one-read manifest diagnostics, dependency-root deduplication,
  missing roots, changed manifests between invocations, changed `PUDU_LIB`, unique ordered standard
  roots, and a memoized missing module diagnosed at both importing spans.
- The optimized complete Haskell regression suite passes with 200 QuickCheck cases per property.
- The clean repository gate run passes the warning-free optimized build, complete optimized suite,
  formatter, diagnostic-code, release-plan, API-coverage, residency, generated-project scaffold,
  typed lint, LSP session, LSP robustness, and documentation-site checks.
- `git diff --check` passes, all three implementation modules remain below 500 lines, and the
  implementation, mirrors, MOC, changelog, and handoff are synchronized.

## Referenced by

[[handoffs/_MOC]] · [[Compiler Program]] · [[Compiler Library]] · [[Compiler Manifest]]
