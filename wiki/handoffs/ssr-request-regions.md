---
date: 2026-11-25
topic: ssr-request-regions
to_role: Architect
status: READY
tags: [handoff, native, ssr]
---

# Handoff — SSR after compile-time chrome

## Where the request path stands

| Change | Effect (native, website) |
|---|---|
| htmlRender kernel (#998) | page render one pass into one buffer |
| kept constants (#1000) | constant tables built once |
| always-fitting conversions (#1005), ASCII case (#1002) | per-byte and per-header costs removed |
| catalogue index, footer and masthead rendered at compile time (website commits on dev) | about page about +32%, home about +21%, 200 crawled pages byte-identical |
| parallel native compilation units (#1009), URL kernel (#1010), borrowed operands (#1011) | module page about 575 to about 900 requests a second combined; native website build about 50 s |
| Std.Html.Memo (#1015) | data-dependent shared fragments kept by key; a 24-link footer page 9× faster |
| void base fix (#1016) | native and interpreter agree on every void element; 150 crawled pages identical |

## Measured and not shipped

- Moving loop-body locals' last reads (TailMove inside loops): 903/903 passing, no measurable website change; elements are still retained once out of the array.
- Lending parameters a function never writes or moves (#1012, notes on the issue): 903/903 passing, no measurable change; the move pass already turns most parameters' last reads into moves.
- Copying small aggregate helpers into every native compilation unit: corrupted the heap; ThinLTO made it unnecessary.

## What remains

- Request regions: per-request memory for page trees and parsed headers, released in one step, so the reference counting a request's own values do disappears. This is a runtime memory design (which values may enter a region, how a value that escapes the request is copied out, how regions interact with the run gate and kept constants), and needs an Architect decision before code.
- Response writes: measured; the one remaining copy (head plus body concatenation) is about 3 µs of a 1.6 ms request, so it is not worth changing at this scale.
- One runtime per core: the server is bound to one core by the run gate (about 20,000 new connections a second); multi-core needs per-core runtimes and an Architect decision.

## Exact next action

Write the request-region design page under wiki/architecture/ answering: which allocations a request region owns, the copy-out rule for a value stored beyond the request, and how a region is released when the response is sent.
