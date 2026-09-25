---
type: handoff
status: COMPLETE
date: 2026-09-21
issue: 270
tags: [handoff, evaluator, linking, startup, performance]
aliases: [2026-09-21-linked-registry]
---

# Linked Registry Handoff

## Objective

Resolve issue #270: linking resolves imports from a per-evaluation registry of linked modules
instead of scanning every accumulated frame, and a module's environment no longer grows with the
number of modules linked before it.

## Ownership and role transitions

1. **Runtime Engineer:** [[Eval Program]] owns linking and the published registry frame.
2. **Forensic Guardian:** reconciles source, mirror, changelog, and this handoff. No separate review
   agent is used at the repository owner's direction.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close it without a pull request.

## Contract

- One published frame holds every linked module's declarations under canonical `Path.name` keys,
  grown by one insertion per declaration; it is created and discarded with the evaluation.
- A module links in `[declarations, import aliases, builtins, published-so-far, beneath]`; its
  functions and methods are scoped to that. Builtins still precede other modules' names, and a
  module sees modules linked before it, as before.
- Whole-module imports read the registry by their path's ordered key range; selected imports look
  their path-qualified names up in it. Imported aliases are never republished.
- The root and interactive blocks run over the published frame as before.

## Measurement

Optimized build, same host, `bench/request.mjs --requests 300 --at-once 4`, two alternating runs
each; process start to `listening` for the full-stack example.

| Measure | Before | After |
|---|---:|---:|
| `/plain` median, one at a time | 1.46–1.55ms (646–683/s) | 0.97–1.03ms (970–1029/s) |
| `/json` median | 1.38–1.51ms | 0.96–0.99ms |
| `/page/pudu` median | 1.81–1.93ms | 1.29–1.31ms |
| allocation to `listening`, warm cache | 148.2MB | 111.2MB |
| allocation to `listening`, no cache | 605.8MB | 568.8MB |

Concurrent throughput at four connections is within noise.

## Completion evidence

- The optimized complete suite passes, including the linking test that holds published names to a
  module's own declarations and the import-chain fixture.

## Exact next action

None for #270.

## Referenced by

[[handoffs/_MOC]] · [[Eval Program]]
