---
type: handoff
status: COMPLETE
date: 2026-09-20
issue: 263
tags: [handoff, stdlib, html, bytes, performance]
aliases: [2026-09-20-bounded-html-output]
---

# Bounded HTML Output Handoff

## Objective

Resolve issue #263 with an explicit application-output byte bound that preserves concatenated input
exactly, splits oversized inputs without copying their slices, and makes no promise about packet or
frame boundaries.

## Ownership and role transitions

1. **Language Architect:** [[Std Html Buffer]] settles additive compatibility, typed invalid-limit
   behavior, application-output terminology, and the distinction from transport framing.
2. **Runtime Engineer:** owns `Std/Html/Buffer.pudu` and its mirror.
3. **Test Engineer:** owns the bounded-coalescing cases in `UsesHtmlServer.pudu` and their explicit
   fixture result in `ProtocolSpec.hs`.
4. **Forensic Guardian:** reconciles source, mirror, MOC, changelog, measurement, and this handoff
   after the repository gates pass.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close it without a pull request. Production validation and source/vault parity
remain required. No separate review agent is used.

## Contract

- `coalesceToMss` remains source- and behavior-compatible, including its best-effort treatment of an
  input larger than its parameter.
- `coalesceBounded` accepts only a positive `maxBytes`; otherwise it returns `CoalesceError` carrying
  the rejected maximum.
- Every successful output chunk has length at most `maxBytes`, and joining all outputs reconstructs
  every non-empty input byte in order.
- Empty input chunks do not create empty output chunks.
- Oversized inputs are divided with storage-sharing `Bytes.slice`. `Bytes.join` copies only batches
  containing multiple pieces; a one-piece batch is returned unchanged.
- The maximum describes application-visible byte arrays. It does not describe TCP packets, TLS
  records, HTTP chunks, writes, flushes, or delivery timing.

## Measurement

The optimized same-machine probe used a 1,460-byte maximum and repeated 5,000 times over an empty
chunk, 100- and 200-byte chunks, and 2,820- and 2,720-byte oversized chunks. Each run produced four
1,460-byte outputs. Two outputs joined a small chunk with an oversized slice, while two remained
single shared slices.

| Quantity | Observed |
|---|---:|
| total application output | 29,200,000 bytes |
| payload crossing `Bytes.join` | 14,600,000 bytes |
| payload retained as shared slices | 14,600,000 bytes |
| elapsed time | 0.51s |
| process maximum RSS | 88,670,208 bytes |
| whole-probe heap allocation | 2,014,906,448 bytes |

The allocation and memory figures include compiler/runtime startup and evaluation on one macOS host.
The copy totals follow the documented `Bytes.slice` and `Bytes.join` contracts for this exact input
shape. None of these measurements is a service-latency or network-boundary guarantee.

## Exact next action

Run the focused formatter and complete repository gates, reconcile any generated documentation,
then commit directly to `dev`, post the commit on issue #263, close it, and continue to issue #264.

## Completion evidence

- `UsesHtmlServer.pudu` checks without diagnostics and returns all 48 focused assertions.
- The warning-free optimized build, complete optimized test suite, formatter, diagnostic-code,
  release-plan, API-coverage, residency, scaffold, lint, LSP session/robustness, and documentation-site
  gates pass.
- `git diff --check` passes, `Std.Html.Buffer` remains below 500 lines, and source/mirror/MOC/changelog
  parity is complete.

## Referenced by

[[handoffs/_MOC]] · [[Std Html Buffer]] · [[src/Std/_MOC]]
