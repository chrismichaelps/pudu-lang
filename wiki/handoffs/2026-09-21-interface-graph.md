---
type: handoff
status: COMPLETE
date: 2026-09-21
issue: 268
tags: [handoff, compiler, types, startup, performance]
aliases: [2026-09-21-interface-graph]
---

# Interface Graph Handoff

## Objective

Resolve issue #268 by preparing a module graph's shared type-interface facts once per program and
giving each module only a small overlay, and remove the confirmed allocation hot spots on the same
startup path.

## Ownership and role transitions

1. **Compiler/Semantic Engineer:** owns [[Type Interface Graph]], [[Type Check Install]],
   [[Type Check Import]], [[Type Interface]], [[Type Check]], [[Type Env]], [[Compiler]], and
   [[Compiler Program]]; lexer and parser changes in [[Symbol Scanner]], [[Token]], the trivia
   scanner, and the parser state.
2. **Test Engineer:** `GraphSpec.hs` and the `test-fixtures/interfacegraph` programs.
3. **Forensic Guardian:** reconciles source, mirrors, MOC, changelog, measurement, and this handoff
   after gates. No separate review agent is used at the repository owner's direction.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close it without a pull request.

## Contract

- One [[Type Interface Graph]] per compiled program: dependency order, formation names, trait table,
  defaults, collected declarations, installed shared names, and implemented traits are formed once.
- Consumer overlays are exact: its own interface is excluded from identities, traits, and defaults;
  an interface importing the consumer forms names without it.
- Global implementation discovery, private formation shells, same-spelling identities, imported
  defaults, ambiguity diagnostics, and unsafe/comptime restrictions are unchanged.
- No checker variables are shared unresolved; the installed snapshot carries the next variable.
- A dependency's formation diagnostic is reported once, by that dependency.
- Nothing persists across invocations.

## Behaviour corrected

- A formation mistake in a dependency was repeated once per importing module (`E3030` four times
  for one declaration); it is now reported once.
- Records naming each other across an import cycle were given a non-canonical identity on one side
  ("expected Node.Node, found Node"); the shared collection gives both sides canonical identities.

## Measurement

Optimized GHC 9.10.3 build, same macOS host, baseline built from `0a93f093` in a separate worktree.

| Measure | Before | After |
|---|---:|---:|
| `check examples/fullstack/Main.pudu`, median | 0.745s | 0.302s |
| same, heap allocation | 1,918,712,184 bytes | 492,077,232 bytes |
| same, maximum residency | 72,783,184 bytes | 44,763,032 bytes |
| same, maximum resident set | 237MB | 168MB |
| process start to `listening`, best of 5 | 745.8ms | 355.1ms |
| minimal one-module program, median | 13ms, 2.0MB | 13ms, 1.7MB |

`bench/graph.mjs` sparse graphs, best of three:

| Modules | Before | After |
|---:|---:|---:|
| 25 | 73.5ms, 84.0MB | 46.3ms, 28.7MB |
| 50 | 182.6ms, 253.6MB | 62.0ms, 56.7MB |
| 100 | 548.0ms, 871.5MB | 97.0ms, 113.9MB |
| 200 | 2917.8ms, 3281.4MB | 196.2ms, 231.3MB |

Allocation per doubling fell from x3.0–x3.8 to x2.0: the repeated whole-graph work is gone.

Contributions, measured step by step on the full-stack check: allocation-free qualifier lookup
(1.92GB to 1.07GB), graph preparation of collection (to 885MB), first-character trivia and symbol
dispatch with constant keyword and symbol maps (to 763MB), unboxed parser steps (to 732MB), shared
installation and contribution skipping (to 605MB), then a lexer cursor that reads characters in
place and slices lexemes from the source, and a line table built line by line (to 492MB, 0.302s,
355.1ms to `listening`). An unboxed checker monad was measured, gained nothing, and was not kept.

## Completion evidence

- Focused tests: one diagnostic for a dependency's mistake across three importers; every interface
  ordered once and after what it imports; a cyclic record pair checks and runs.
- The optimized complete suite and the repository gate script pass.

## Exact next action

None for #268. Continue with #269.

## Referenced by

[[handoffs/_MOC]] · [[Type Interface Graph]]
