---
type: handoff
status: ACTIVE
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
   The current presenter slice additionally owns `Std/Ui/Desktop.pudu`, `Pudu/Eval/Desktop.hs`,
   the private macOS adapter, launch fixtures, and their complete mirrors.
3. **Validation:** focused fixtures and `test/gates.sh` protect each slice. Further review sub-agents
   are disabled at the user's explicit direction.

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
- `a1d9181` — `Std.Ui.Text` original bitmap face, 21 assertions; canvas span search makes a
  400-character paragraph draw and render in 1.40 s (from 3.22 s).
- `3567c73` — layout text leaves with extent-based damage (40 assertions) and visible recolorable
  focus rings on screens (20 assertions).
- `c1eebc5` — `Std.Audio` exact byte-backed PCM, time, gain, mix, slices, and WAV (30 assertions).
- `47feac0` — `Std.Audio.Graph` stateless pull-model nodes with slice-independent renders (21).
- `749c84a` — `Std.Video` exact timing and tracks (19); screens skip unchanged views (21).
- `8b724f8` — the canvas never composes commands under an opaque region-covering command (43);
  300 stacked fills render in 0.14 s instead of 4.38 s.
- `e74ccd1` — typed text and erasing reach only a focused field (screen 27).
- `52ed91c` — windowed scroll stacks with clips for painting, hit testing, and damage (layout 46,
  text 22).
- `1405cbb` — clamped `ScrolledTo` events for the tagged scrolling node under the pointer (screen 31).
- Resampling slice — exact resampling, downmix, upmix, and channel maps (audio 42).
- Crypto breadth slice — SHA3-256/512, BLAKE2b-256/512, HMAC-SHA512, constant-time byte comparison,
  and secure key/nonce generation; crypto 59 assertions and the optimized full gate pass.
- Native desktop slice — `Std.Ui.Desktop` owns checked window plans and explicit open/present/pump/
  close sessions; the evaluation-local store serializes use against close and tears down leaks. A
  private macOS AppKit/CoreGraphics adapter exposes no framework value to Pudu and links no foreign
  UI toolkit. `LaunchUiDesktop.pudu` opened, displayed, pumped, and closed a real 480×280 titled
  desktop window with `Ok(1)`. The full Cabal suite passed after integration.
- Packaging observation — `cabal check` still rejects a source archive because the existing test
  suite uses `hs-source-dirs: ../../../test`, outside the nested package root. This predates the
  presenter and does not affect its build or launch, but it remains a serious-release packaging gap.
  It is recorded rather than expanded here because the active user direction is UI/audio/video only.

## Exact next action

Continue exclusively with native UI, audio, and video. Build the first Pudu **space** application
loop over [[Std Ui Desktop]] and [[Std Ui Screen]]: translate native pointer/key/text/close events into
screen inputs, present only after state or focus changes, and expose lifecycle transitions without
copying SwiftUI's protocol/property-wrapper graph. Then add menus, settings, documents, multiple
windows, IME, and platform accessibility export in independently grilled slices. Keep every exact
fixture as the semantic oracle and add percentile latency/memory gates before claiming interactive or
real-time performance.

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
- **Q:** Does avoiding foreign UI integration forbid calling the operating system? **A:** No.
  _Rationale:_ a real window must connect to a window server. _Accepted:_ a private target adapter
  whose pointers and framework types never cross the Pudu boundary. _Rejected:_ raylib, SDL,
  SwiftUI, AppKit-shaped public APIs, and program-authored foreign declarations.

## Referenced by

[[handoffs/_MOC]] · [[First Release Readiness]] · [[Native Application UI]] · [[Std Ui Canvas]]
