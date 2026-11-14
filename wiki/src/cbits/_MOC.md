---
type: moc
tags: [moc, module, foreign, ffi]
---

# Native Boundary Module Map

- [[Pudu FFI Bridge]] — the C/libffi adapter that turns a checked crossing description into one
  native call.
- [[Pudu FFI C++ Fixture]] — the test-only C++ resource surface exported through a stable C ABI.

- [[Pudu SQLite Bridge]] — on-demand SQLite loading, statement ownership, and exact byte transport.
- [[Pudu Desktop Header]] — framework-neutral private ABI for desktop target plumbing.
- [[Pudu Desktop Adapter]] — macOS window, bitmap presentation, event pumping, and release.
- [[Pudu Desktop Host]] — the window host and frame view shared by the adapter's translation units.
- [[Pudu Desktop Menu]] — the application's menu bar from presented records, and the records it holds.
- [[Pudu Desktop Window]] — window-state records and configured density, limits and full screen.
- [[Pudu Desktop Access]] — a window's accessibility elements from a presented snapshot, and AppKit's report of them.
- [[Pudu Audio Header]] — framework-neutral bounded device-playback ABI and stable statuses.
- [[Pudu Audio Adapter]] — macOS Audio Queue ownership, preallocation, refill, deadline, and release.
- [[Pudu Audio Stream Header]] — framework-neutral persistent-output ABI, snapshot layout, and stable statuses.
- [[Pudu Audio Stream Adapter]] — macOS persistent Audio Queue sessions, bounded writes, controls,
  hardware timeline, telemetry, and release.

- [[Desktop Presentation Test]] · [[Desktop Presentation Gate]] — native presentation orientation regression.

- [[iOS Host Adapter]] — iOS host embedded into application builds, never compiled into the compiler (#916).

- [[iOS Host Layout]] — vertical viewport, safe area, keyboard layout and focus reveal.

## Referenced by

[[src/_MOC]] · [[Foreign Call]] · [[ADR-0018 Calling a Library Written Elsewhere]]