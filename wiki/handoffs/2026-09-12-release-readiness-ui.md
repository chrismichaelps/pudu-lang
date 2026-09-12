---
type: handoff
status: IMPLEMENTING
issue: 193
tags: [handoff, release, stdlib, ui]
---

# Release Readiness and Native UI Canvas

## Objective

Correct the stale first-release table against implemented behavior, then begin the explicitly desired
native application UI/audio/video row. Raylib and Apple publications are architecture and
performance references only: this implementation uses no foreign integration and exposes no
game-engine or platform-framework vocabulary. Work is
committed directly to `dev` at the user's explicit direction; no branch or PR is created.

## Ownership and roles

1. **Language Architect:** owns [[First Release Readiness]], [[Native Application UI]], and the
   Pudu-native/no-foreign boundary.
2. **Stdlib Implementer:** owns `packages/pudu/v0.1/lib/Std/Ui/Canvas.pudu`,
   `test-fixtures/stdlib/UsesUiCanvas.pudu`, their mirrors, and the exact-count service fixture
   registration.
3. **Independent Reviewer:** reviews the completed diff without editing and classifies findings P0–P3.
4. **Forensic Guardian:** checks mirror fidelity, MOC links, changelog evidence, and the private-input
   boundary before delivery.

Other work exists in the repository. This slice does not alter the preserved untracked website probe
or the commits on `feature/228-std-prose`.

## Contract

`Std.Ui.Canvas` is a bounded Pudu-native RGBA software renderer. It owns pure geometry, a flat ordered
fill list, overflow-safe clipping, opaque replacement, integer source-over blending, and exact
framebuffer inspection. It neither opens a window nor binds a native toolkit.

## Exact next action

After committing the exact-pixel conformance slice, add a repeatable canvas benchmark and replace
whole-frame immutable copies with a Pudu-native bounded renderer that meets an interactive percentile
deadline. Keep the current output fixture as the semantic oracle; do not begin widgets or a presenter
until the renderer passes that gate.

## Grill Log

- **Q:** Link raylib? **A:** No. _Rationale:_ it is a reference for explicit frame ownership and flat
  commands, while the user requires the package and audio core to be Pudu-native. _Rejected:_ foreign
  bindings.
- **Q:** Call the first framebuffer a full desktop toolkit? **A:** No. _Rationale:_ layout, text,
  accessibility, input, windows, and device audio remain named slices. _Rejected:_ a readiness claim
  broader than the implementation.
- **Q:** Optimize before exact output exists? **A:** No. _Rationale:_ pixel conformance is the oracle
  against which later batching and damage-region optimizations are checked. _Rejected:_ speed without
  a stable result.

## Referenced by

[[handoffs/_MOC]] · [[First Release Readiness]] · [[Native Application UI]] · [[Std Ui Canvas]]
