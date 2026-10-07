---
type: handoff
status: ACTIVE
issue: 448
tags: [application, reload, delivery]
---
# Application Hot Reload Delivery

Language Architect resolves [[Std App Reload]]. Runtime Engineer owns the reload middleware,
App.run integration, exact fixture and registration. Work remains sequential. Language Architect
and Forensic Guardian independent review precede integration.

Run an application with `pudu run --watch path/Main.pudu`; source saves restart it and refresh
connected successful HTML pages. Add `--also path/assets` before the entry path to watch assets.
The ordinary run path carries no refresh middleware. Application dependencies remain parameters
and closures; optional package implementations stay internal to the application boundary.

## Evidence

Exact fixtures pass in direct and packed evaluation. The optimized full compatibility suite passes.
Formatting, lint and whitespace checks pass. The dependency policy from issue #447 accepts 215
modules and 96 framework dependencies with zero findings. Removing script injection in a temporary
library makes the exact fixture fail at `external script appended`.

A live page refreshed from `source-one` to `source-two` after a source save, then displayed
`asset-two` after a watched asset save, with no manual navigation. A rejected save produced the
expected source diagnostics and left the previous page visible; correcting it refreshed to
`source-three`. The ordinary application served unchanged HTML and returned 404 for both reserved
resources. The default protective headers remained present throughout.

Exact next action: obtain independent semantic and vault-parity review before integration.

## Referenced by

[[handoffs/_MOC]] · [[Std App Reload]]
