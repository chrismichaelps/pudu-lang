---
type: module
path: "@root/lib/Std/Ui/Desktop.pudu"
fidelity: Active
tags: [module, stdlib, ui, desktop]
aliases: [Std Ui Desktop]
---

# Std Ui Desktop

## Purpose and interface

Own the portable contract between a Pudu-rendered `Std.Ui.Canvas.Surface` and a real desktop
window. `WindowPlan` states caption, initial extent, resizability, and pixel budget. `Session` is an
opaque runtime token paired with the admitted extent. `open`, `present`, `pump`, and `close` expose
the complete first resource lifetime; `showFor` is a bounded launch smoke built from those four
operations rather than a second presenter.

`signals(session)` drains what the person did since the last drain as `Signal` values:
`Input(Screen.Input)`, `Shortcut(chord)` for Command/Control chords written `cmd+shift+z`, and
`Resized(size)`. `decodeSignals(text)` is the pure parser beneath it, so input mapping is tested
without a window. `drive(session, screen, frameMillis, onShortcut)` runs a screen until the person
closes the window: inputs go to `Screen.handle`, shortcuts to `onShortcut` (a returned state
re-renders through `Screen.restated`), and a frame is presented only when a turn damaged it.
`DriveError` separates window failures from frame failures.

Every operation returns `Result`. Invalid dimensions, titles, durations, malformed surfaces,
closed or invented tokens, wrong-thread access, unsupported targets, and platform failures remain
distinguishable `DesktopError` variants. Closing twice is a typed `SessionClosed` outcome. Runtime
teardown closes an unclosed session.

## Ownership and boundaries

The module contains no `foreign` declaration and exposes no target framework type. It calls
language-owned desktop effects whose resource store belongs to one evaluation. Pixel bytes are
copied into platform-owned presentation storage before the effect returns, so later Pudu buffer
updates cannot race drawing. The initial presenter accepts only the opaque, exact-size RGBA surface
produced by Canvas; it does not redraw, scale, or reinterpret alpha.

`pump` joins the platform event loop for at most the stated milliseconds and reports whether the
person requested close. It does not run an ambient background loop. A long pump is served in native
slices of at most 16 ms, so an interrupt stops the program within a slice rather than after the whole
duration, and a program watching for a stop request sees the pump answer early. The later application-space
layer will translate platform events into `Std.Ui.Screen.Input` while retaining this explicit
session ownership.

## Negative logic

- No platform framework or third-party toolkit value enters the Pudu type graph.
- No global public window and no successful headless fallback.
- No unbounded event wait, silent resize, implicit pixel conversion, or use-after-close.
- No claim that this static first presenter completes menus, documents, IME, accessibility, audio,
  video, or accelerated composition.

## Grill Log

- **Q:** Start with a one-call `show` primitive? **A:** No. _Rationale:_ it hides the resource and
  prevents a real application loop from presenting subsequent frames. _Rejected:_ a blocking host
  demo API as the foundation.
- **Q:** Expose native pointers to Pudu? **A:** No. _Rationale:_ integers can be forged and native
  ownership cannot be copied safely. _Accepted:_ runtime-issued tokens checked against an
  evaluation-local store.
- **Q:** Name the declarative layer after the reference framework's scenes? **A:** No. _Rationale:_ Pudu will use
  independently designed spaces and window plans; this low-level session has no framework-shaped
  protocol surface. _Rejected:_ renamed one-for-one declarations from another framework.
- **Q:** Treat an unavailable display server as success in tests? **A:** No. _Rationale:_ the
  acceptance requirement is an actual window. _Rejected:_ framebuffer-only launch claims.

## Referenced by

[[Native Application UI]] · [[Std Ui Canvas]] · [[Stdlib MOC]] · [[Uses Ui Desktop]] · [[Launch Ui Desktop]]
