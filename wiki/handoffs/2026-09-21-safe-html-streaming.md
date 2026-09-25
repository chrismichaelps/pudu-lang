---
type: handoff
status: COMPLETE
date: 2026-09-21
issue: 265
tags: [handoff, stdlib, html, streaming, safety]
aliases: [2026-09-21-safe-html-streaming]
---

# Safe HTML Streaming Handoff

## Objective

Resolve issue #265 with reusable safe document heads and typed suspense helpers that keep text,
markup, destinations, stylesheet source, and HTML/JavaScript identifiers in explicit domains.

## Ownership and role transitions

1. **Language Architect:** [[Std Html Stream]] and [[Std Html]] settle additive compatibility,
   explicit trust types, the boundary alphabet, and output behavior.
2. **Runtime Engineer:** owns `Std/Html/Stream.pudu` and its mirror.
3. **Test Engineer:** owns `UsesHtmlSafeStream.pudu` and its explicit result in `ServiceSpec.hs`.
4. **Forensic Guardian:** reconciles source, mirrors, MOC, changelog, and this handoff after gates.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close it without a pull request. Production validation and source/vault parity
remain required. No separate review agent is used.

## Contract

- Legacy `documentHead` and byte suspense helpers remain unchanged, explicitly unchecked, and
  available for source compatibility.
- `prepareHead` escapes title and metadata through `Std.Html`, accepts only typed preload
  destinations, and accepts stylesheet source only as explicit `TrustedCss`. `PreparedHead` retains
  immutable bytes for reuse.
- Safe placeholder, replacement, error, and paired helpers accept `Html`; ordinary `Html.text`
  remains escaped, and raw markup requires `Html.trusted` at the call site.
- Boundary IDs are non-empty ASCII alphanumerics. Refusal happens before an ID reaches either an
  HTML attribute or inline JavaScript string, so one encoding is not misapplied to another context.
- Existing documented replacement and error scripts remain byte-compatible for admitted IDs.

## Measurement boundary

This change makes no speedup, allocation reduction, TTFB, or complexity claim. It adds validation
and typed rendering before the existing byte assembly; actual flush timing belongs to the consuming
server and requires end-to-end measurement.

## Exact next action

Run the complete repository gates, reconcile generated documentation, then commit directly to
`dev`, post the commit on issue #265, close it, and continue to issue #266.

## Completion evidence

- `UsesHtmlSafeStream.pudu` checks without diagnostics and returns all 18 focused assertions.
- The warning-free optimized build, complete optimized test suite, diagnostic-code, release-plan,
  API-coverage, residency, scaffold, lint, LSP session/robustness, and documentation-site gates pass.
- The repository-wide formatter gate reports three pre-existing files changed by the intervening
  `d3060482` commit: `Std/Log.pudu`, `Std/Toml/Read.pudu`, and `UsesLog.pudu`. The exact formatter
  check passes for every Pudu file owned by this issue; the unrelated files remain untouched.
- `git diff --check` passes, `Std.Html.Stream` remains below 500 lines, and
  source/mirror/MOC/changelog parity is complete.

## Referenced by

[[handoffs/_MOC]] · [[Std Html Stream]] · [[Std Html]] · [[src/Std/_MOC]]
