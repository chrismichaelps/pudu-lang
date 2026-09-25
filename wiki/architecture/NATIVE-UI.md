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
does not bind platform UI frameworks or another foreign UI/media toolkit.

“Better than Apple” is a verification target, not a marketing claim. Pudu must match the mature
properties visible in Apple's public design—stable frame pacing, short-lived presentable resources,
role-complete accessibility, timestamped media, and explicit real-time audio processing—then exceed
them where language design can help: typed failures, capability-visible device access, deterministic
headless behavior, platform-neutral conformance fixtures, explicit memory/latency budgets, and one
coherent ownership model across UI, audio, and video.

[[Desktop Capability Conformance]] is the executable coverage ledger for this architecture. A gap
in that ledger is an implementation obligation unless it is explicitly excluded as framework
machinery rather than an application capability.

## Lessons taken from small media libraries

Small explicit media libraries are a reference for layering rather than a dependency. Their useful decisions are a
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

The public model is intentionally familiar without being framework-shaped. An application owns a
model and reduces input into a new model; a **space** describes one independently managed piece of
desktop UI; a **window plan** describes a family of windows; and a **desktop session** is the
linear, runtime-owned connection to one platform window. These are Pudu value types and functions,
not subclasses, delegates, property wrappers, opaque result builders, or an imitation of Apple's
protocol graph. The first presenter exposes the session beneath the later declarative application
layer so its lifetime, failure, and pixel transfer can be tested directly.

On macOS the language-owned runtime adapter may call the operating system's public AppKit and
CoreGraphics entry points. That is platform plumbing, not a foreign integration exposed by the UI
package: no AppKit value, callback, selector, memory rule, or framework type crosses into Pudu.
Third-party and foreign UI toolkits are not linked. Other targets
must implement the same presenter contract or answer `UnsupportedPlatform`; a successful no-op is
forbidden.

## Declarative desktop benchmark, Pudu contract

The platform's own declarative UI framework is the primary behavioral reference for the application layer. Pudu keeps the useful
human model while making ownership, cost, and failure more explicit:

| Reference capability | Pudu-native contract | Required improvement |
| --- | --- | --- |
| App and scene composition | model-driven application containing named spaces | plain values and functions; no hidden global application object |
| A reusable window scene | a window plan instantiated as independently owned sessions | per-window state identity and resource limits are explicit |
| State and environment propagation | immutable model input plus typed, explicit dependencies | no string keys, ambient mutable environment, or wrapper-specific lifetime rules |
| View layout and modifiers | one `View` value with deterministic measure/place and named fields | modifier order cannot silently change unrelated semantics |
| Focus and accessibility focus | separate keyboard and assistive focus channels over the same semantics tree | focus movement is inspectable and headlessly reproducible |
| Commands, settings, and documents | typed command routes and specialized spaces | unsupported platform behavior is a typed failure, never omitted silently |
| Platform rendering | bounded surface presenter below a portable display list | exact CPU reference output, damage information, and measured transfer cost |
| Lifecycle phases | explicit transitions delivered as input | transition order and shutdown ownership are fixture-testable |

The similarity ends at the problem model. Pudu will not reproduce that framework's spellings, generic
signatures, protocol conformances, property-wrapper conventions, builder syntax, or AppKit's
responder/delegate hierarchy. Public documentation supplies expected desktop behavior; Pudu's API
is independently designed from the language's values, `Result`, exhaustive sums, capabilities,
and structured resource lifetimes.

## Desktop concept coverage

Every concept a complete desktop application needs, where it lives, and whether it is usable today.
A row marked **Absent** is queued work, not an exclusion.

| Concept | Pudu module | Status |
| --- | --- | --- |
| Window lifetime and presentation | [[Std Ui Desktop]] `plan`, `open`, `present`, `close` | **Ready** on macOS; other targets answer `UnsupportedPlatform` |
| Live input: presses, keys, text, scroll, chords, resize | [[Std Ui Desktop]] `signals`, adapter queue | **Ready** on macOS |
| Run loop | [[Std Ui Desktop]] `drive` | **Ready**: presents only damaged turns |
| One source of truth, view derived from state | [[Std Ui Screen]] `start`, `handle`, `restated` | **Ready** |
| Shared settings and appearance | explicit values ([[Std Ui Theme]]) passed to views | **Ready** by design; no ambient environment |
| Light and dark appearance, design tokens | [[Std Ui Theme]] | **Ready**, contrast audited |
| Stacks, layers, padding, alignment, scrolling | [[Std Ui Layout]] | **Ready** |
| Grids | — | **Absent** |
| Text measure, wrap, draw | [[Std Ui Text]] | **Ready** (bitmap face); shaping, bidirectional text, and input methods absent |
| Controls: buttons, toggles, steppers, pickers, progress, fields, secure fields | [[Std Ui Controls]] | **Ready**; sliders **Absent** until pointer motion |
| Long lists | [[Std Ui Virtual]] | **Ready**; selection model **Absent** |
| Navigation stack, split view, tabs | [[Std Ui Navigation]] | **Ready** |
| Sheets, alerts, confirmations | [[Std Ui Navigation]] `presenting` | **Ready**: presses blocked, focus trapped |
| Drawing | [[Std Ui Canvas]] rectangles, clipping, blending | **Partial**: paths, strokes, gradients absent |
| Animation | [[Std Ui Motion]] curves, springs, retargeting | **Ready** |
| Gestures | press through `Screen.Pressed` | **Partial**: drag, long press, magnify need pointer move and release |
| Keyboard focus | [[Std Ui Screen]] focus order and ring | **Ready** |
| Keyboard shortcuts | [[Std Ui Keymap]] | **Ready** |
| Menus and commands | [[Std Ui Menu]] in-window bar | **Ready**; the platform's native menu bar **Absent** |
| Undo and redo | [[Std Ui History]] | **Ready** |
| Persisted preferences | [[Std Ui Preferences]] | **Ready**, atomic replace |
| Clipboard, drag and drop | — | **Absent** (adapter work) |
| Accessibility semantics | [[Std Ui Layout]] semantics, required names | **Partial**: export to the platform accessibility tree absent |
| Multiple windows, documents, settings window | multiple sessions | **Partial**: no document or settings space yet |

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
5. Exact PCM, frame-counted time, gain, mixing, bounded slices, and WAV in `Std.Audio`, and a
   stateless pull-model render graph in `Std.Audio.Graph`, with exact resampling and channel maps;
   then device presenters once native capability contracts exist.
6. Exact fractional rates and timestamps, ordered picture tracks, and audio alignment in `Std.Video`;
   then color/HDR metadata, seeking, and a small uncompressed reference codec foundation.
7. A bounded desktop session that opens, presents, pumps, and closes a real platform window; then
   application spaces, multiple windows, menus, settings, documents, clipboard, drag/drop,
   dialogs, pointer/keyboard/IME input, accessibility export, display-scale/color changes, and
   device-loss recovery.

## Device audio boundary

The first device presenter is bounded clip playback, not graph execution on the hardware callback.
`Std.Audio.Device` validates exact PCM plus buffer count, quantum, and monotonic deadline before one
runtime effect. The private target adapter preallocates every hardware queue buffer, refills them
outside the callback, and lets the callback perform only bounded atomic completion bookkeeping. It
returns the exact frames acknowledged by the device or a typed timeout/platform failure, and tears
down the queue on every path.

This gives ordinary applications an audible, owned capability without pretending the interpreted
graph is real-time. It remains `PARTIAL` until streaming sessions expose device discovery and format
negotiation, interruptions/device loss, pause/resume, volume, underrun telemetry, and a shared clock
for picture presentation. Other targets must implement the same behavior or report unsupported.

## Comparative release gates

The package may claim next-generation quality only after evidence exists for keyboard-only and
screen-reader completion of reference applications; bidirectional and complex-script text; wide
gamut/HDR round trips; stable frame pacing under resize and background load; glitch-free audio under
the documented device quantum; hour-scale A/V synchronization; deterministic screenshots and audio
goldens; cancellation and device-loss recovery; and bounded behavior under malformed media. These are
release gates, not deferred aspirations.

## Public references

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

- [Metal tile-based deferred rendering](https://developer.apple.com/documentation/metal/tailor-your-apps-for-apple-gpus-and-tile-based-deferred-rendering)
  — never read back what will be covered, and avoid redundant opaque overdraw; guidance for the canvas
  rasterizer and any later accelerated backend, not for the declarative layer.
- [NSApplication](https://developer.apple.com/documentation/appkit/nsapplication),
  [NSWindow](https://developer.apple.com/documentation/appkit/nswindow), and
  [AppKit input](https://developer.apple.com/documentation/appkit/mouse-keyboard-and-trackpad) —
  macOS event-loop and window-server obligations used only inside the target adapter.
- [Creating a custom Metal view](https://developer.apple.com/documentation/metal/creating-a-custom-metal-view)
  and [smooth frame rates with a Metal display link](https://developer.apple.com/documentation/metal/achieving-smooth-frame-rates-with-a-metal-display-link)
  — later accelerated presentation must track the window's display, synchronize with it, and keep
  the portable render contract independent of the GPU API.

Apple references are the developer documentation archive and the public platform UI and Metal
documentation. Every contract above is restated
in Pudu's own terms; no API names, type hierarchies, or code are carried over.

## Grill Log

- **Q:** Copy an immediate-mode global drawing API? **A:** No. _Rationale:_ a global drawing context hides
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
- **Q:** Reproduce the reference framework's public declaration graph with renamed identifiers? **A:** No.
  _Rationale:_ cosmetic renaming would retain hidden lifetime and composition constraints while
  creating unnecessary intellectual-property risk. _Rejected:_ one-for-one renamed protocols,
  property wrappers, builders, and modifiers.
- **Q:** Can a Pudu desktop application avoid every operating-system call? **A:** No. _Rationale:_ a
  real window must join the target's window server and event loop. _Accepted boundary:_ a private,
  language-owned adapter to public OS entry points whose handles and types never cross into Pudu.
  _Rejected:_ binding a foreign UI toolkit or exposing platform UI framework types as the Pudu API.

## Referenced by

[[architecture/_MOC]] · [[First Release Readiness]] · [[Std Ui Canvas]]
