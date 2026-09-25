---
type: architecture
status: ACTIVE_DESIGN
tags: [architecture, ui, desktop, appkit, testing, conformance]
aliases: [Desktop Capability Conformance]
---

# Desktop Capability Conformance

## Purpose

Define the behavioral surface a serious Pudu desktop application needs and attach executable
evidence to every claim. Apple's public AppKit and declarative UI documentation are the primary maturity
references, not APIs to reproduce. Pudu covers user capabilities and operating-system obligations;
it does not copy class names, protocol graphs, delegates, selectors, builders, or deprecated
compatibility layers.

“All AppKit APIs” is neither a finite quality gate nor Pudu's goal. AppKit includes Objective-C
object infrastructure, Interface Builder serialization, legacy cell architecture, deprecated APIs,
and platform-specific implementation mechanisms. The conformance target is complete desktop
application capability with Pudu-native types, effects, ownership, tests, and performance budgets.

## Status vocabulary

- **WORKING:** implementation plus automated semantic tests and a real-device launch test where a
  device is involved.
- **PARTIAL:** useful behavior exists, but at least one release-critical obligation remains named.
- **MISSING:** no public Pudu contract or no real implementation exists.
- **EXCLUDED:** framework machinery that is not an application capability and will not be copied.

No row advances from partial because a demo looks correct. It needs success, failure, lifecycle,
recovery, accessibility, and percentile performance evidence appropriate to the capability.

## Capability ledger

| Desktop domain | Status | Present evidence | Release-critical gap / next test |
| --- | --- | --- | --- |
| Application startup and shutdown | PARTIAL | evaluator-owned resources; real bounded launch | persistent application loop, activate/deactivate, reopen, orderly termination |
| Windows | PARTIAL | checked single window, exact surface present, close request | resize/move/minimize/fullscreen, scale/display changes, restoration, multiple windows |
| Declarative state and composition | PARTIAL | `Std.Ui.Screen` state/view/update and deterministic damage | application spaces, typed dependencies, lifecycle delivery, async work ownership |
| Drawing and compositing | PARTIAL | exact bounded RGBA Canvas, clipping, alpha, damage repaint | paths, transforms, images, gradients, shadows, layers, wide color, GPU backend |
| Layout | PARTIAL | rows, columns, layers, scroll windows, deterministic focus order | adaptive constraints, grids, tables, split views, safe areas, scale-aware layout |
| Text display | PARTIAL | original exact bitmap face and wrapping | Unicode shaping, bidi, fallback, typography, selection, rich text, GPU glyph cache |
| Keyboard, pointer, and gestures | PARTIAL | screen-level press/action/text/scroll vocabulary | native event translation, modifiers, repeat, hover, capture, gestures, key equivalents |
| Text input and IME | MISSING | focused field accepts already-composed text | marked text, composition ranges, candidates, selection, clipboard, dictation |
| Controls | PARTIAL | button/field semantics and activation | toggles, choices, sliders, steppers, pickers, progress, lists, tables, outlines |
| Focus | PARTIAL | deterministic keyboard focus and visible focus ring | native focus bridge, assistive focus, window focus, focus scopes and restoration |
| Accessibility | PARTIAL | layout-time named role tree with bounds | native accessibility elements, actions, notifications, value/state, VoiceOver trials |
| Menus and commands | MISSING | none | application/menu-bar/context menus, validation, shortcuts, command routing |
| Toolbars and title-bar controls | MISSING | none | typed toolbar model, customization, state restoration, accessibility |
| Dialogs, sheets, popovers, panels | MISSING | none | modal ownership, open/save/color/font panels, cancellation and focus return |
| Documents | MISSING | filesystem primitives only | open/save/autosave, dirty state, versions, recent files, conflict recovery |
| Undo and redo | MISSING | none | grouped reversible commands, menu state, document integration |
| Clipboard and services | MISSING | none | typed formats, ownership changes, copy/paste, service/share boundaries |
| Drag and drop | MISSING | none | typed offers, promised files, cancellation, security-scoped access |
| Cursors and pointer confinement | MISSING | none | cursor selection, hide/show balance, confinement and recovery |
| Notifications and attention | MISSING | none | user permission, delivery, activation routing, badges and attention policy |
| Printing and PDF | MISSING | none | pagination, preview, print settings, cancellation, vector output |
| Localization and input direction | PARTIAL | server locale module and Unicode strings | desktop locale environment, pluralization, bidi layout mirroring, live change |
| Audio representation and graph | WORKING | exact PCM, WAV, resampling, channel maps, bounded pull graph | remains working as pure media; device presentation is a separate row |
| Speaker/device audio | PARTIAL | bounded clip plus persistent default-device stream; adapter-accepted format; two-to-eight preallocated buffers; bounded partial writes; pause/resume/volume; hardware-clock, underrun, interruption, device-change, and timeline-failure telemetry; real macOS launches | device discovery/selection, active route-change recovery, latency calibration, long-run percentile evidence, Windows/Linux adapters |
| Video timing and picture tracks | WORKING | rational clocks, non-overlap, exact audio-frame alignment | remains working as pure media; codec/device presentation are separate rows |
| Video presentation | PARTIAL | animated Canvas surfaces reach a real window; late pictures drop against the audio clock | display-link pacing, bounded presentation queue, resize, color/HDR, device loss |
| Media codecs and containers | MISSING | PCM WAV only | bounded image/audio/video codecs, metadata, malformed corpus and fuzzing |
| A/V device synchronization | PARTIAL | picture selection follows the content-bounded hardware audio-queue clock; configured launch submitted all 16,016 audio frames and presented 27 of 30 pictures by dropping late pictures | output-latency calibration, drift correction, pause/seek/rate, display clock correlation, hour-scale measurement |
| Capture devices | MISSING | none | permission, camera/microphone discovery, bounded queues, interruption handling |
| GPU acceleration | MISSING | exact CPU renderer is the oracle | Metal/D3D/Vulkan-or-native target backend, frame pacing, fallback parity |
| Objective-C/AppKit class compatibility | EXCLUDED | not an application capability | never reproduce framework inheritance, delegates, selectors, cells, or NIB ABI |
| Deprecated AppKit behavior | EXCLUDED | none | retain only a migration note if a real application requires one |

## Media laboratory

`examples/media/Studio.pudu` is the configurable integration probe. It:

1. loads a nested JSON workload or checked defaults, refusing unsafe dimensions, waits, media
   bounds, cross-media duration, and artifact names before device acquisition;
2. renders an exact bounded audio graph in caller-sized slices and writes a valid WAV in the system
   temporary folder;
3. drives frame time from `Std.Video.Rate` and verifies the exact audio frame aligned to each picture;
4. renders changing frames entirely through `Std.Ui.Canvas`;
5. opens one real `Std.Ui.Desktop` session, presents every frame, pumps native events, and closes on
   normal completion or recoverable failure;
6. writes a JSON conformance report with effective configuration, artifacts, observed counts,
   monotonic phase durations, and honest `WORKING`/`PARTIAL`/`MISSING` capability states.

This proves a bounded media pipeline, not media completeness. PCM reaches the macOS default speaker
through one persistent stream, and pictures follow its content-bounded hardware timeline. The latest
480×270 configured run prepared and submitted all 16,016 stereo frames at 16 kHz, presented 27 of 30
pictures by intentionally dropping late pictures, reported no underruns, interruptions, or device
changes, and closed cleanly. One transient timeline query before the queue established time was
retained as telemetry rather than treated as playback failure.

Pictures are generated rather than decoded; event pumping observes only close; and no display-link,
latency calibration, route recovery, or hour-scale drift gate exists. Exact compiled tone/ramp byte
kernels keep preparation near 55 ms, while callbacks perform bounded atomic bookkeeping only; graph
evaluation still never runs on the real-time callback.

## Reference-derived obligations

- AppKit's application object owns the main event loop, application lifecycle, windows, menus, and
  event distribution. Pudu keeps the obligation but uses an evaluation-owned application space and
  typed event values rather than a global object.
- AppKit windows both display content and distribute keyboard/pointer events. A Pudu window is not
  complete until both presentation and native event translation pass.
- Apple's accessibility guidance requires informational properties, actions, and change
  notifications, with role-specific requirements for custom controls. A static semantic tree alone
  is therefore partial.
- Apple's sample-buffer playback model synchronizes queued audio and video to one timeline. Exact
  timestamp conversion is necessary but not sufficient; device-clock and drift evidence remain.

## Public references

- [AppKit](https://developer.apple.com/documentation/appkit)
- [NSApplication](https://developer.apple.com/documentation/appkit/nsapplication)
- [NSWindow](https://developer.apple.com/documentation/appkit/nswindow)
- [Windows, panels, and screens](https://developer.apple.com/documentation/appkit/windows-panels-and-screens)
- [Menus, cursors, and the Dock](https://developer.apple.com/documentation/appkit/menus-cursors-and-the-dock)
- [Documents, data, and pasteboard](https://developer.apple.com/documentation/appkit/documents-data-and-pasteboard)
- [Toolbar](https://developer.apple.com/documentation/appkit/toolbar)
- [Accessibility for AppKit](https://developer.apple.com/documentation/appkit/accessibility-for-appkit)
- [Custom accessibility controls](https://developer.apple.com/documentation/appkit/custom-controls)
- [Sample buffer playback](https://developer.apple.com/documentation/avfoundation/sample-buffer-playback)
- [Creating a custom Metal view](https://developer.apple.com/documentation/metal/creating-a-custom-metal-view)

## Grill Log

- **Q:** Make one checklist row per AppKit symbol? **A:** No. _Rationale:_ that measures imitation,
  includes deprecated machinery, and says nothing about whether a user can complete a task.
  _Accepted:_ capability domains with observable conformance tests and links to reference areas.
- **Q:** Mark audio/video complete because their pure models are exact? **A:** No. _Rationale:_ a
  media application also needs devices, queues, clocks, codecs, interruption, and recovery.
  _Rejected:_ pure fixtures as device evidence.
- **Q:** Hide missing rows until their API is designed? **A:** No. _Rationale:_ the laboratory exists
  to expose gaps early. _Accepted:_ visible missing rows with one exact next test.
- **Q:** Use the media example as a release gate? **A:** Not alone. _Rationale:_ examples are manual
  integration probes; deterministic fixtures, malformed-input suites, device launch records, and
  performance history remain required. _Rejected:_ demo-driven readiness.

## Referenced by

[[Native Application UI]] · [[First Release Readiness]] · [[2026-09-12-release-readiness-ui]]
