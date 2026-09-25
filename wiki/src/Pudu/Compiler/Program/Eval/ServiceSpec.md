---
type: module
path: "@root/test/Pudu/Compiler/Program/Eval/ServiceSpec.hs"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, test, service, evaluation]
aliases: [Service Evaluation Spec]
---

# Service Evaluation Spec

## Purpose and interface

Runs the Pudu fixtures for database, application lifecycle, HTML, UI, validation, authentication,
observability, scheduling, localization, and caching. Every fixture returns an exact assertion count;
the Haskell property attaches a contract-specific counterexample to that count.

## Governance and algorithm

The UI fixture counts cover pure component state, structural differences, the Pudu-native canvas'
exact pixels, repaint equality, and typed refusals, and declarative layout's exact frames,
accessibility semantics, and damage that repaints to the same bytes as a full render, and interactive
screens whose incremental frames after routed input equal a fresh start at the same state, bitmap
text whose measures, wrapping, and glyph pixels are exact, PCM audio whose samples, time, and WAV
bytes are exact, audio graphs whose split renders equal whole ones, and video timing and tracks that are
exact over long streams. Exact equality is intentional: adding a check without registering it
or skipping a branch changes the count and fails the host suite.

[[Deep Renderer Fixture]] crosses the former evaluator-frame failure boundary with program-built
HTML, JSON, and UI values. It checks compact and pretty serialization, deep change discovery, and
deep immutable patch application—including refusal of a deep invalid path—through their public
Pudu APIs, with an exact count like every other service fixture.

The desktop fixture keeps the standard suite display-independent by checking unsafe caption,
extent, pixel-budget, and pump-duration paths before a platform effect is reached. The separate
[[Launch Ui Desktop]] fixture is the macOS acceptance gate and must open an actual window; its
success is not inferred from this pure count.

The device-audio fixture likewise keeps CI display-independent: it covers every invalid one-shot and
persistent plan, PCM refusal, volume bound, close bound, and stale large capability before
native acquisition. [[Launch Audio Device]] and [[Launch Audio Stream]] are separate hardware
acceptance gates; the latter must also prove controls, telemetry, and a progressing queue timeline.

The Media Studio configuration fixture is also evaluated here with an exact count of eight, so the
example's device-queue fields cannot drift from its decoder or admitted bounds unnoticed.

`UsesUiToolkitAll` packs six two-digit counts into `100808060709`: desktop signal decoding and
restating (10), theme (8), motion (8), history (6), list windowing (7), and keymap (9). Driving a real
window runs only under `PUDU_DESKTOP_DRIVE=1`, because CI has no display.

`UsesUiControlsAll` packs `1215`: controls (12) and navigation with modal presentation (15).

`UsesUiAppShellAll` packs `90804`: preferences (9), menus (8), and focus trapping (4).

## Grill Log

- **Q:** Accept a count greater than a minimum? **A:** No. _Rationale:_ a skipped refusal could be
  hidden by an unrelated added success. _Rejected:_ lower-bound fixture assertions.
- **Q:** Put UI patch validation only in Haskell? **A:** No. _Rationale:_ the public API is written
  in Pudu and must be exercised as its callers exercise it. _Rejected:_ duplicating its semantics in
  the host test language.
- **Q:** Treat a renderer process exit as sufficient depth evidence? **A:** No. _Rationale:_ an
  iterative traversal may survive while emitting wrong order or incomplete output. _Accepted:_ a
  Pudu fixture with exact semantic assertions registered in this host property. _Rejected:_ an
  unregistered manual stress script.

Resolved Grill Log: exact counts keep every Pudu-level assertion observable while named Haskell
counterexamples identify the failed service contract.

## Referenced by

[[Std Ui]] · [[Std Ui Canvas]] · [[Std Ui Layout]] · [[Std Ui Screen]] ·
[[Std Ui Desktop]] · [[Deep Renderer Fixture]] · [[2026-09-12-release-readiness-ui]]
