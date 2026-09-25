---
type: handoff
status: COMPLETE
date: 2026-09-21
issue: 269
tags: [handoff, evaluator, startup, performance]
aliases: [2026-09-21-untallied-entry]
---

# Untallied Entry Handoff

## Objective

Resolve issue #269: an ordinary `pudu run` no longer allocates evaluator counters or updates a tally
map at every name lookup and tally site while linking and initializing the program.

## Ownership and role transitions

1. **Runtime Engineer:** [[Eval Program]] owns the shared entry action.
2. **Forensic Guardian:** reconciles source, mirror, changelog, and this handoff. No separate review
   agent is used at the repository owner's direction.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close it without a pull request.

## Contract

- One action links dependencies, scopes the root, and calls — and, when asynchronous, awaits — the
  entry point. `evaluateProgramEntry` runs it with no counters; `evaluateProgramTallied`, the
  `explain` entry, runs the same action with counters and returns them.
- Both run under the same runtime runner, so lifecycle and teardown are identical.

## Measurement

The counters were cheap: time to `listening` for the full-stack example is unchanged within noise
(366.6ms best with the change against 367.1ms without it). The work removed is per-lookup map
updates on every ordinary run.

## Completion evidence

- The optimized complete suite passes, including tallied `explain` coverage and runtime tests.

## Exact next action

None for #269.

## Referenced by

[[handoffs/_MOC]] · [[Eval Program]]
