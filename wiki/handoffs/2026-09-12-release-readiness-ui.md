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
   `packages/pudu/v0.1/lib/Std/Ui/Layout.pudu`, `test-fixtures/stdlib/UsesUiCanvas.pudu`,
   `test-fixtures/stdlib/UsesUiLayout.pudu`, their mirrors, and the exact-count service fixture
   registrations.
3. **Independent Reviewer:** reviews the completed diff without editing and classifies findings P0–P3.
4. **Forensic Guardian:** checks mirror fidelity, MOC links, changelog evidence, and the private-input
   boundary before delivery.

Other work exists in the repository. This slice does not alter the preserved untracked website probe
or the commits on `feature/228-std-prose`.

## Contract

`Std.Ui.Canvas` is a bounded Pudu-native RGBA software renderer. It owns pure geometry, a flat ordered
fill list, overflow-safe clipping, opaque replacement, integer source-over blending, and exact
framebuffer inspection. It neither opens a window nor binds a native toolkit. It rasterizes by bands
and spans, and `repaint` redraws damaged regions with byte equality to `render`.

`Std.Ui.Layout` is the declarative layer above it: `View` values with modifiers as fields, two-pass
placement, exact grow distribution, a semantics tree that refuses unnamed meaningful roles, focus
order, hit testing, painting, and damage regions.

## State

- `bc50f06` — exact-pixel canvas and the corrected readiness audit.
- `fd6cfd3` — band-and-span rasterizer and repaint; 512×512 frame 4.35 s → 0.10 s at -O2.
- `a1cb1c5` — declarative layout; 1,001 nodes place in about 0.18 s and paint plus render in about
  0.56 s at -O2, which is interpreter cost and not yet an interactive frame.
- `2b45bea` — `Std.Ui.Screen` routes presses and action keys to tagged controls and repaints only
  damage; layout gained tags. Layout 33 and screen 16 assertions.
- Text slice — `Std.Ui.Text` original bitmap face, 21 assertions; canvas span search makes a
  400-character paragraph draw and render in 1.40 s (from 3.22 s).

## Exact next action

Put text into layout as a leaf view whose intrinsic size is its measure and whose paint draws it, with
the text as its accessible name; then a visible focus indicator, text entry, and scrolling on
`Std.Ui.Screen`. Profile the remaining second of rendering many small rectangles before claiming any
interactive frame rate. Audio (`Std.Audio`: PCM frames, pull-model render slices, rational time) follows
the UI event slice. Keep every fixture as the semantic oracle for later optimization.

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
