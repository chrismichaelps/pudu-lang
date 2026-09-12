---
type: architecture
status: ACTIVE_DESIGN
tags: [architecture, stdlib, ui, graphics, audio, video]
aliases: [Native Application UI]
---

# Native Application UI

## Purpose

Provide a Pudu-native, performance-conscious application-media stack whose portable rendering,
layout, event, accessibility, audio, and video logic is written in Pudu. It is not a game engine and
does not bind raylib, Apple frameworks, or another foreign UI/media toolkit.

“Better than Apple” is a verification target, not a marketing claim. Pudu must match the mature
properties visible in Apple's public design—stable frame pacing, short-lived presentable resources,
role-complete accessibility, timestamped media, and explicit real-time audio processing—then exceed
them where language design can help: typed failures, capability-visible device access, deterministic
headless behavior, platform-neutral conformance fixtures, explicit memory/latency budgets, and one
coherent ownership model across UI, audio, and video.

## Lessons taken from raylib

Raylib is a reference for small explicit layers rather than a dependency. Its useful decisions are a
clear frame boundary, a flat drawing API, clipping as explicit state, batched rendering, input polled
at a known point, and device resources with visible open/close lifetimes. Pudu keeps those properties
but rejects the game-shaped surface, ambient global window/audio state, and APIs whose success cannot
be expressed as typed failure.

The first implementation is a retained display list rendered into an owned RGBA byte surface. A
backend can consume the flat surface without understanding widgets. Layout, focus, text, semantics,
window presentation, speaker presentation, media timelines, and video presentation remain separate
modules so none is hidden inside a monolithic loop.

## Native boundary

No `foreign` declaration belongs in `Std.Ui`, `Std.Audio`, or `Std.Video`. The portable layers end in
owned data: color-managed image planes, interleaved or planar PCM frames, timestamped video planes,
and synchronized media packets. Presenting those values in a real window, speaker, camera, or codec
device is inherently platform interaction. That interaction must be implemented as an explicit Pudu
platform module using language-owned capabilities available on that target; until such a capability
exists, the portable result can be tested, encoded, streamed, or written without claiming that a
device was opened.

## Performance and quality constitution

- A frame has separate update, render, and present phases. Present targets are acquired late,
  released early, and never ambient globals.
- All clocks use rational media time rather than binary floating point. Audio sample positions and
  video presentation/decode timestamps remain exact across long sessions.
- The audio render path performs no unbounded allocation, lock acquisition, logging, or blocking I/O;
  automation is sample-addressed and underruns are observable typed events.
- Color spaces, transfer functions, alpha representation, pixel aspect, HDR mastering metadata, and
  tone mapping are explicit values. Silent conversion is forbidden.
- Accessibility semantics are produced with layout, not reverse-engineered from final pixels. Every
  interactive role has statically required name, value/state, actions, focus behavior, and bounds.
- Every queue and pool has backpressure, capacity, and a declared drop/degrade policy. Interactive
  work favors newest input; archival media never silently drops data.
- CPU reference renderers and mixers define exact conformance. Accelerated implementations may vary
  only within published numerical tolerances and must pass the same fixtures.
- Performance claims require percentile frame/audio deadlines, peak resident memory, allocation
  counts, and degraded-device evidence; average throughput alone is insufficient.

## First vertical slice

`Std.Ui.Canvas` owns logical integer geometry, RGBA colors, a bounded frame, ordered rectangle fill
commands, clipping, opaque fast replacement, source-over alpha blending against the opaque surface,
pixel inspection, and framebuffer extraction. Bounds arithmetic widens before adding so an extreme
coordinate cannot overflow while being clipped. A frame has a configurable pixel budget so dimensions
supplied by an untrusted document cannot select an arbitrary allocation.

## Planned slices

1. Canvas rectangles and exact pixels.
2. Lines, rounded rectangles, paths, and damage regions.
3. Text: an original bitmap face with measuring, wrapping, and merged glyph rectangles
   (`Std.Ui.Text`) and text views in layout; then shaping and bidirectional runs, and a Pudu-native
   outline-coverage rasterizer held to the same exact-pixel fixtures.
4. Declarative layout with focus order, hit testing, an accessibility semantics tree, and damage
   regions (`Std.Ui.Layout`); press and key routing with state-driven damage repaint
   (`Std.Ui.Screen`). Text entry, scrolling, and a visible focus indicator follow text layout.
5. PCM samples, a real-time-safe graph, mixing, resampling, channel layouts, and WAV encoding in
   `Std.Audio`.
6. Rational clocks, frame planes, color/HDR metadata, synchronization, seeking, and a small
   uncompressed/reference codec foundation in `Std.Video`.
7. Per-platform window/input, speaker, camera, and display presenters after their native capability
   contracts exist.

## Comparative release gates

The package may claim next-generation quality only after evidence exists for keyboard-only and
screen-reader completion of reference applications; bidirectional and complex-script text; wide
gamut/HDR round trips; stable frame pacing under resize and background load; glitch-free audio under
the documented device quantum; hour-scale A/V synchronization; deterministic screenshots and audio
goldens; cancellation and device-loss recovery; and bounded behavior under malformed media. These are
release gates, not deferred aspirations.

## Public references

- [raylib source and public API](https://github.com/raysan5/raylib) — explicit frame and resource
  organization, used only as architectural evidence.
- [Apple Metal frame-rate guidance](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/FrameRate.html)
  and [drawable lifetime guidance](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/Drawables.html)
  — stable presentation and late acquisition of scarce presentable resources.
- [Apple triple-buffering guidance](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/TripleBuffering.html)
  and [persistent-object guidance](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/PersistentObjects.html)
  — bounded in-flight work and render-loop allocation avoidance.
- [Apple view drawing optimization](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CocoaViewsGuide/Optimizing/Optimizing.html)
  — coalesced invalidation regions, opaque content, and drawing only what intersects damage.
- [Apple Core Animation basics](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/CoreAnimationBasics/CoreAnimationBasics.html)
  — separating the described state from the frame being presented.
- [Apple accessibility programming guide](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/index.html)
  — an element hierarchy with role-specific required properties.
- [Apple media representations](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/06_MediaRepresentations.html)
  — rational time values and half-open time ranges.
- [Apple Core Audio overview](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/WhatisCoreAudio/WhatisCoreAudio.html)
  and [Audio Unit fundamentals](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioUnitProgrammingGuide/AudioUnitDevelopmentFundamentals/AudioUnitDevelopmentFundamentals.html)
  — sample/frame/packet vocabulary, pull-model render slices, and real-time processing rules.
- [OpenSwiftUI](https://github.com/OpenSwiftUIProject/OpenSwiftUI) (MIT) — read for the shape of
  declarative parent/child size negotiation and dependency-driven invalidation; no code is used.

Apple references are limited to the developer documentation archive. Every contract above is restated
in Pudu's own terms; no API names, type hierarchies, or code are carried over.

## Grill Log

- **Q:** Copy raylib's immediate global API? **A:** No. _Rationale:_ a global drawing context hides
  ownership and makes concurrent or headless rendering difficult to test. _Rejected:_ ambient
  `BeginDrawing`/`EndDrawing` state.
- **Q:** Start with widgets? **A:** No. _Rationale:_ widgets depend on stable geometry, rendering,
  input, focus, text, and accessibility contracts. _Rejected:_ attractive controls over an undefined
  platform core.
- **Q:** Use floating coordinates everywhere? **A:** No for the first surface. _Rationale:_ logical
  integer pixels make clipping and exact conformance deterministic; transforms can introduce floats
  in a later, separately grilled layer. _Rejected:_ NaN and rounding semantics in the foundation.
- **Q:** Hide platform presentation behind a successful no-op? **A:** No. _Rationale:_ producing a
  framebuffer and opening a window are observably different capabilities. _Rejected:_ pretending a
  headless renderer is already a desktop presenter.
- **Q:** Clone Apple framework types? **A:** No. _Rationale:_ their public documentation supplies
  mature constraints, but reproducing framework-shaped class hierarchies would import legacy and
  platform coupling. _Rejected:_ an AppKit/AVFoundation/Core Audio compatibility facade as the core.
- **Q:** Promise superiority before benchmarks and accessibility trials? **A:** No. _Rationale:_ the
  comparison is useful only as a falsifiable bar. _Rejected:_ branding without percentile latency,
  correctness, recovery, and assistive-technology evidence.

## Referenced by

[[architecture/_MOC]] · [[First Release Readiness]] · [[Std Ui Canvas]]
