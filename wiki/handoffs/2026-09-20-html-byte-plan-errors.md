---
type: handoff
status: COMPLETE
date: 2026-09-20
issue: 258
tags: [handoff, stdlib, html, buffer, correctness]
aliases: [2026-09-20-html-byte-plan-errors]
---

# HTML Byte-Plan Error Handoff

## Objective

Resolve issue #258 with additive checked ordinary and compact byte-plan assembly that reports
missing values, invalid public metadata, capacity overflow, refused copies, and inconsistent final
lengths while preserving both permissive renderers.

## Ownership and role transitions

1. **Language Architect:** [[Std Html Buffer]] settles the additive error type, compatibility, and
   missing-versus-empty contract.
2. **Runtime Engineer:** owns `Std/Html/Buffer.pudu` and its mirror.
3. **Test Engineer:** owns `UsesHtmlCompact.pudu` and its explicit result in `ServiceSpec.hs`.
4. **Forensic Guardian:** reconciles source, mirror, MOC, changelog, and this handoff after gates.

The repository owner directed this delivery to avoid separate review-agent execution. These roles
describe the completed engineering passes within one implementation flow.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close it without a pull request. Production validation and source/vault parity
remain required.

## Contract

- `renderToBytes` and `renderCompactToBytes` retain their permissive behavior and signatures.
- `renderChecked` and `renderCompactChecked` resolve dynamic bytes in document order before
  allocation. Missing names return `MissingSlot`; present empty bytes remain valid; repeated names
  reuse one resolved value at every original output position.
- Public static totals and compact block lengths are recomputed. Negative or mismatched metadata is
  refused, and checked addition prevents capacity overflow.
- Writing propagates `Buffer.copy` refusal without advancing the cursor. Bytes are exposed only when
  the final cursor equals the validated allocation length.

## Exact next action

Commit directly to `dev`, post the commit on issue #258, close it, and continue to issue #259,
“Retain encoded SSR response bytes and exact lengths.”

## Completion evidence

- `UsesHtmlCompact.pudu` checks without diagnostics and returns all 29 focused assertions.
- Ordinary and compact success paths match the existing permissive outputs exactly.
- Failure checks cover missing values, supplied empty values, repeated slots, mismatched ordinary
  metadata, negative metadata, checked overflow, mismatched compact block lengths, and mismatched
  compact totals.
- Full repository gate evidence is recorded before delivery.
- `git diff --check` passes, source files remain below 500 lines, and source/mirror/MOC/changelog
  parity is complete.

## Referenced by

[[handoffs/_MOC]] · [[Std Html Buffer]] · [[src/Std/_MOC]]
