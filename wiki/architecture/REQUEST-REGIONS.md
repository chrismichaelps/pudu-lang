---
type: architecture
status: proposed
date: 2026-11-25
tags: [architecture, native, ssr, memory]
aliases: [Request Regions]
---
# Request regions

Status: proposed — needs Architect approval before any runtime code.

## Problem

Native server requests spend most of their time on memory bookkeeping, not on the work. On the website's request profile, retaining and releasing references is about a quarter of active CPU and the allocator about a sixth more. Almost every value a request builds — page trees, builder nodes, rendered text, parsed headers, route parameters — dies when the response is sent. Counting references to values that all die together, and freeing them one by one, is pure overhead. Two attempts to remove counts inside the existing model (moves inside loop bodies, lending unmodified parameters) passed the full suite but measured flat, because the counts left are structural.

## Proposal

A request region is memory a request allocates from and releases in one step when its response has been sent.

| Piece | Rule |
|---|---|
| Activation | The HTTP server opens a region before calling a request handler and closes it after the response is written. The active region is per thread, so the run gate and worker threads need nothing new. |
| Allocation | While a region is active, boxes, text storage and array storage come from the region: bump allocation in chunks of the thread's own memory. |
| Marking | A region object carries a mark in its count word. Retain and release of a marked object do nothing, and nothing frees it one by one. |
| Release | Closing the region resets its chunks for the next request. A region past a size limit returns its extra chunks to the allocator. |
| Interpreter | Regions do not exist there; the evaluator's memory is already managed for it. Output is identical with or without them. |
| Public surface | None. Regions are opened and closed inside `Std.Http.Server`; programs change nothing. |

## Escape rule

A region value must never be reachable after its region closes. Every runtime entry that keeps a value beyond the current request copies region values into ordinary memory first ("evacuates" them, deeply, at that moment):

| Escape point | Why it keeps a value |
|---|---|
| `Std.Sync` cell writes | a cell outlives the request (this also covers `Std.Html.Memo`) |
| channel sends and task starts | another thread may read the value later |
| kept module constants | built on first read, which may happen inside a request, and kept for the run |
| host stores (open handles, sockets, foreign claims, callbacks) | the host keeps the value |
| the response handed to the server | sent before the region closes, so it may stay in the region |

A second rule closes the remaining path: while a region is active, only region objects are updated in place. An ordinary object reached from a request — application state, a loaded catalogue — is treated as shared, so an update copies it into the region rather than writing region pointers into ordinary memory.

## Evidence plan

- Forced mode: a test setting wraps every program's `main` in a region, and the full property suite runs with it, so every escape point is exercised by hundreds of programs (the same method that validated parallel C units).
- Poisoning: a debug build fills a closed region with a fixed pattern, so a missed escape fails loudly instead of reading stale memory; sanitizer runs on the parity programs.
- Measurement: the website's module, home and about pages and the request benchmark, before and after, with pages byte-identical.

## Phases

| Phase | Delivers |
|---|---|
| 1 | Region allocator, the count mark, no-op counting for marked objects, behind a setting, off by default |
| 2 | Evacuation at every escape point, and shared treatment of ordinary objects during a region |
| 3 | `Std.Http.Server` opens and closes a region per request |
| 4 | Forced-mode suite and poisoning green; measurement; setting on by default for servers |

## Questions for the Architect

1. Region size limit per request, and what happens past it: keep growing with chunks, or fall back to ordinary allocation for the rest of the request.
2. Streaming responses (server-sent events, chunked pages): one region per message, or one per connection with periodic release.
3. Whether kept constants should always be built with the region suspended, instead of evacuated, to keep the escape set smaller.
4. Whether forced mode stays a permanent test setting in continuous integration.

## Exact next action

On approval: phase 1 — the region allocator and the count mark behind a setting, with the full suite green with the setting off and on for programs that never escape.
