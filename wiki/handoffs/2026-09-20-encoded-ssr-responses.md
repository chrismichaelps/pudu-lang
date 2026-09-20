---
type: handoff
status: COMPLETE
date: 2026-09-20
issue: 259
tags: [handoff, stdlib, html, ssr, bytes, performance]
aliases: [2026-09-20-encoded-ssr-responses]
---

# Encoded SSR Response Handoff

## Objective

Resolve issue #259 with an additive byte-native SSR plan that retains encoded static runs and exact
lengths, encodes each unique used dynamic slot once per request, exposes segmented bytes, and uses
checked assembly for optional contiguous completion.

## Ownership and role transitions

1. **Language Architect:** [[Std Html SSR]] and [[Std Html Buffer]] settle the additive plan,
   segmented result, error, compatibility, and request-isolation contracts.
2. **Runtime Engineer:** owns `Std/Html/Ssr.pudu`, `Std/Html/Buffer.pudu`, and their mirrors.
3. **Test Engineer:** owns `UsesHtmlCompact.pudu` and its explicit result in `ServiceSpec.hs`.
4. **Forensic Guardian:** reconciles source, mirrors, MOC, changelog, and this handoff after gates.

The repository owner directed this delivery to avoid separate review-agent execution. These roles
describe the completed engineering passes within one implementation flow.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close it without a pull request. Production validation and source/vault parity
remain required.

## Contract

- `prepareBytes` joins and encodes one static block per complete adjacent run and preserves every
  slot boundary in a checked compact byte plan. It never stores request values.
- `byteSegments` visits slots in document order, renders and encodes each unique used `Html` value
  once for that request, reuses its bytes at repeated positions, and returns exact total bytes without
  joining them.
- `finishBytes` retains those dynamic encodings through capacity accounting and delegates one
  contiguous exact-size allocation to the checked assembler.
- Empty output and supplied empty slot bytes succeed. UTF-8 multibyte scalars and escaping count by
  encoded byte length, not by text characters.
- `Plan`, `chunks`, `render`, `finish`, and `renderWithin` retain their signatures, chunking, output,
  and error order.

## Measurement

The warm optimized same-machine probe prepared 12,000 adjacent fixed `Html.text("é<&")` pieces and
two occurrences of one slot, then completed 500 132,016-byte responses. The legacy path used
`prepareCompact` plus `finish`; the retained-byte path used `prepareBytes` plus `byteSegments`.

| Measure | Legacy text | Retained segments |
|---|---:|---:|
| heap allocated | 1,131,969,376 bytes | 1,041,871,032 bytes |
| process maximum RSS | 97,026,048 bytes | 94,961,664 bytes |
| elapsed | 0.28s | 0.28s |

The retained path reduced measured heap allocation by 8.0% and process maximum RSS by 2.1%. These
figures include compiler and evaluator startup and are one-host comparative evidence, not service
latency, network, or portable complexity guarantees. Source-path accounting additionally verifies
one UTF-8 encoding per complete static run at preparation and one per unique used slot per request;
repeated slot positions reuse the retained dynamic bytes.

## Exact next action

Commit directly to `dev`, post the commit on issue #259, close it, and continue to issue #260,
“Prepare reusable typed HTML shells with nested slots.”

## Completion evidence

- `UsesHtmlCompact.pudu` checks without diagnostics and returns all 39 focused assertions.
- Exact output and length checks cover empty bodies, multibyte text, escaping, repeated slots,
  request isolation, missing slots, segmented output, contiguous output, and legacy parity.
- Full repository gate evidence is recorded before delivery.
- `git diff --check` passes; owned source files remain below 500 lines; source, mirrors, MOC,
  changelog, and handoff are aligned.

## Referenced by

[[handoffs/_MOC]] · [[Std Html SSR]] · [[Std Html Buffer]] · [[src/Std/_MOC]]
