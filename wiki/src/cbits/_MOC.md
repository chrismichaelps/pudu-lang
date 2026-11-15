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
- [[iOS Host Theme]] — semantic color roles, appearance override, and Dynamic Type text styles.
- [[iOS Host Events]] — private event queue with the text and detail word each event carries.
- [[iOS Host Controls]] — platform control factories, setters, target actions and self-test actions.
- [[iOS Host List]] — recycling list and grid cells, the row store, and scroll reports.
- [[iOS Host Material]] — surface materials realized as glass on iOS 26 or later, blur otherwise.
- [[iOS Host Gesture]] — UIKit recognizers attached to a control and their gesture events (#930).
- [[iOS Host Feedback]] — alerts presented one at a time, haptics, progress and activity indicators (#930).
- [[iOS Host Access]] — accessibility traits, hints, values and context menus (#930).
- [[iOS Host Scene]] — root controller, scene size and size classes, and lifecycle events (#930).
- [[iOS Host Motion]] — animated groups and one spring per commit, honoring Reduce Motion (#930).
- [[iOS Host Stream]] — view stream reader: words, text fields and stream defects (#930).
- [[iOS Host Capability Test]] — self-test of the capability headers under the capability environment variable (#930).

## Referenced by

[[src/_MOC]] · [[Foreign Call]] · [[ADR-0018 Calling a Library Written Elsewhere]]