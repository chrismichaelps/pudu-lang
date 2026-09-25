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
- [[Pudu Desktop Access]] — a window's accessibility elements from a presented snapshot, and AppKit's report of them.
- [[Pudu Audio Header]] — framework-neutral bounded device-playback ABI and stable statuses.
- [[Pudu Audio Adapter]] — macOS Audio Queue ownership, preallocation, refill, deadline, and release.
- [[Pudu Audio Stream Header]] — framework-neutral persistent-output ABI, snapshot layout, and stable statuses.
- [[Pudu Audio Stream Adapter]] — macOS persistent Audio Queue sessions, bounded writes, controls,
  hardware timeline, telemetry, and release.

## Referenced by

[[src/_MOC]] · [[Foreign Call]] · [[ADR-0018 Calling a Library Written Elsewhere]]
