---
type: handoff
status: COMPLETE
date: 2026-09-21
issue: 266
tags: [handoff, stdlib, html, streaming, performance]
aliases: [2026-09-21-incremental-html-output]
---

# Incremental HTML Output Handoff

## Objective

Resolve issue #266 with pull-based bounded application output that can expose prepared static bytes
before requesting a deferred typed body, while making backpressure, cancellation, and late failures
explicit.

## Ownership and role transitions

1. **Language Architect:** [[Std Html SSR]] and [[Std Html Stream]] settle cursor state, producer
   timing, late-error meaning, application bounds, and the transport boundary.
2. **Runtime Engineer:** owns `Std/Html/Ssr.pudu`, `Std/Html/Stream.pudu`, and their mirrors.
3. **Test Engineer:** owns `UsesHtmlIncremental.pudu` and its explicit result in `ServiceSpec.hs`.
4. **Forensic Guardian:** reconciles source, mirrors, MOC, changelog, measurement, and this handoff
   after gates.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close it without a pull request. Production validation and source/vault parity
remain required. No separate review agent is used.

## Contract

- Beginning a cursor validates only its positive output maximum and invokes no producer.
- One flush returns at most one non-empty byte chunk no larger than the maximum, or completion. It
  does not evaluate later plan parts.
- Accumulated static bytes flush before the following dynamic part, even below the maximum. That
  makes a prepared head or placeholder observable before its body producer runs.
- Each used producer runs at most once per cursor; repeated slots reuse its rendered bytes. Missing
  producers and fallible producer errors occur when traversal reaches that slot, after any earlier
  output has already been committed.
- Cancellation is terminal and prevents remaining producers. Explicit finish drains the cursor into
  bounded chunks without joining them.
- The bound applies to each emitted application chunk and the current batch. A rendered dynamic slot
  and the per-request repeated-slot cache are retained separately; this is not a total-memory bound.
- `Stream.defer` retains a validated typed placeholder without invoking its fallible typed content
  producer. Resolution is a separate explicit call.

## Measurement

An optimized local probe prepared `head` followed by one producer returning 200,000 less-than signs,
whose escaped output is 800,000 bytes. With a 1,460-byte application limit, three runs measured:

| Run | first static chunk | complete application output | remaining chunks |
|---:|---:|---:|---:|
| 1 | 0ms | 34ms | 548 |
| 2 | 0ms | 34ms | 548 |
| 3 | 1ms | 37ms | 548 |

The first measurement ends immediately after the first pull; the complete measurement includes the
producer, escaping, and all later pulls. It does not include a socket, scheduling, client receipt,
or network travel and therefore is not TTFB.

## Exact next action

Run the complete repository gates, record any inherited failures without weakening them, then commit
directly to `dev`, post the commit on issue #266, close it, and continue to issue #267.

## Completion evidence

- `UsesHtmlIncremental.pudu` checks without diagnostics and returns all 22 focused assertions.
- The warning-free optimized build, complete optimized test suite, diagnostic-code, release-plan,
  API-coverage, lint, LSP session, and LSP robustness gates pass in the aggregate run.
- Residency, generated-project scaffold, and documentation-site parity initially failed because the
  host had no usable temporary directory with only 356 MiB free. After removing recoverable `dist`
  and `dist-o2` build artifacts, their exact commands passed with full output.
- The repository-wide formatter gate continues to report the three pre-existing files introduced by
  `d3060482`: `Std/Log.pudu`, `Std/Toml/Read.pudu`, and `UsesLog.pudu`. Every issue-owned Pudu file
  passes the exact formatter check; the unrelated files remain untouched.
- `git diff --check` passes, both implementation modules remain below 500 lines, and
  source/mirror/MOC/changelog parity is complete.

## Referenced by

[[handoffs/_MOC]] · [[Std Html SSR]] · [[Std Html Stream]] · [[src/Std/_MOC]]
