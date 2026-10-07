---
type: module
path: "@root/lib/Std/App/Reload.pudu"
fidelity: Active
tags: [stdlib, application, reload]
aliases: [Std App Reload]
---
# Std App Reload

## Purpose and interface

Automatic page refresh for watched application hosting. `forGeneration` returns no middleware
for an absent or nonpositive generation; a positive generation obtains a fresh random revision.
`watched` reads the watcher generation once at startup. `middleware` validates an explicit revision
and builds the pure request transformation used by exact fixtures. No package wiring is required.

## Algorithm and invariants

Reserve `/_pudu/reload` and `/_pudu/reload.js` only while enabled. GET and HEAD serve an opaque
revision or the same-origin script; other methods receive 405 with Allow. Responses prohibit caching.
The script polls sequentially, pauses while hidden, bounds each request and retries during restart.
Only a successful changed revision triggers refresh. No source names or settings are returned.
Script media types come from [[Std Mime]] rather than a second extension registry.

Append an external script to successful GET text HTML responses. Require an uncompressed response,
no binary override and no range framing. Discard invalidated validators, cache/framing headers and
recompute exact UTF-8 length. Preserve other headers, including the existing security policy.
Non-HTML, unsuccessful, binary, compressed, ranged and HEAD responses remain untouched.
Policies that deliberately prohibit same-origin scripts also prohibit refresh.

## Resolved Grill Log

- **Q:** Require authors to register refresh routes? **A:** No; App.run enables this internally.
- **Q:** Reuse a watcher count as the complete revision? **A:** No; a fresh random revision also
  detects restarting the watcher itself. Entropy failure refuses startup before stages open.
- **Q:** Broaden the security policy for development? **A:** No; use an external same-origin script.
- **Q:** Promise preserved process state? **A:** No; the watcher recreates the process.

## Referenced by

[[Std App]] · [[Uses App Reload]] · [[src/Std/_MOC]]
