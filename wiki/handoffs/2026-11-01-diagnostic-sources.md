---
type: handoff
status: ACTIVE
aliases: [Diagnostic Source Delivery]
tags: [handoff, diagnostics, tooling]
---
# Diagnostic Source Delivery

Issue #777 owns feature/777-related-source-locations, fresh from dev e85b0100e
with fully locally tested #775 prerequisite 8890399f explicitly integrated.
PR #778 remains pending hosted checks. No delegated agents; independent review
is waived for this engine loop, while validation and wiki parity remain required.

Architect → Tooling Engineer ownership: Diagnostic.Render, app/Main.hs,
Diagnostic.RenderSpec and the existing loaded sum-owner gate with all matching
mirrors. No semantic code or diagnostic identity changes. Preserve other worktrees.

## Resolved Grill Log

Related spans retain correct producer offsets, but the renderer interprets them
against the primary file's line index. A filename is not a snapshot identity;
use sameSpanSource against emptySpan to validate an available Source. A stale
snapshot with the same name must never provide a line, column or excerpt.

Add renderDiagnosticsWithSources taking the existing config, an explicit immutable
Map SourceName Source, the primary Source and diagnostics. Existing rendering APIs
remain pure compatibility wrappers with an empty supplementary map. Resolve each
span against the primary snapshot first, otherwise a map candidate with matching
snapshot identity. If unavailable, print its real filename and offset without
an excerpt. No filesystem lookup or guessed source contents belong in rendering.

Display-name and first-line overrides belong only to spans of the primary
snapshot. Foreign snapshots use default coordinates/names while retaining the
selected colour style. Related-note order, messages, primary caret/tab behavior,
summary counts and ordinary same-source output remain stable.

The CLI builds its loaded-source index once per program and passes it to the
renderer for each diagnostic. Replace its linear primary-source lookup with that
same index. Preserve the existing manifest/lock diagnostic fallback. Main's
existing large command module receives only this bounded presentation update;
no additional command or compiler responsibility is introduced.

Properties prove different file line layouts, missing and stale same-name
snapshots, primary display mapping, foreign mapping isolation and existing
same-source controls. The already registered loaded owner gate asserts original
producer line/column notes in both declaration orders and selected/module-alias
consumers across off/cold/warm products. It remains below 500 lines. No new CI
registration is needed because both runners already execute these tests.
Run focused properties and loaded checks, then every clean full optimized gate.

Verification Engineer → Forensic Guardian: the new property and loaded CLI
coordinate assertions failed before repair. Snapshot fallback and available-source
properties now pass 200 checks each; the render-focused suite and loaded owner
gate pass, including off/cold/warm producer coordinates. The optimized warning-clean
build passes. The clean full optimized gate is running with no later source edits.
Existing same-source layout, tabs, summaries and interactive controls stay green.

Exact next action: observe the existing full-gate process and inspect every result;
if green, publish the bounded #777 PR. Observe #778's existing hosted runs and merge
after green checks before further engine features. Do not restart live validation.

## Referenced by

[[handoffs/_MOC]] · [[Diagnostic Render]] · [[Pudu CLI]] · [[Diagnostic Render Properties]] · [[Sum Owner Gate]]
