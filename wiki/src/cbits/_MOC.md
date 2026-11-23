---
type: moc
tags: [moc, module, foreign, ffi]
---

# Native Boundary Module Map

- [[Pudu FFI Bridge]] — the C/libffi adapter that turns a checked crossing description into one
  native call.
- [[Foreign Platform Loader]] — shared platform loading and reference release.
- [[Pudu FFI Callback Bridge]] · [[Pudu Private FFI ABI]] — libffi callbacks and shared ABI carriers.
- [[Pudu FFI Objective-C Bridge]] — Objective-C block invocation, runtime delegate classes, and their release (Apple only).
- [[Pudu FFI Callback Adapter]] — shared adapter struct, block literal layout, and callback lock and dispatch declarations.
- [[Pudu FFI C++ Fixture]] — the test-only C++ resource surface exported through a stable C ABI.

- [[pudu_ios_nodes.h]] — instruction codes, control kinds and the host's node table, shared by the capability headers.
- [[pudu_ios_navigation.h]] — UIKit navigation host: page stack, page sheet, and user pop and dismissal reports.
- [[pudu_ios_refresh.h]] — UIKit refresh control: user pulls reported, the indicator driven by the program's state, and unanswered pulls ended at the next wait.
- [[pudu_ios_fetch.h]] — platform URL session for the program's keyed requests: answers, cancellation, one wake timer and memory warnings.
- [[pudu-android-routes]] — Android host routes: page stack, pull to refresh, requests, cancellation and wake, checked whole before the screen changes (#971).
- [[pudu-ios-kinds]] — kind table of the iOS host, moved out of the host main file, with one entry per control kind (#934).
- [[pudu-ios-image]] — UIKit images: asset and URL sources decoded to the view size, bounded cache, IMAGED report and self-test (#973).
- [[pudu-ios-system]] — UIKit open, share sheet, clipboard and status bar, with their reports and self-test (#974).
- [[pudu-ios-storage]] — user defaults and keychain storage, with the STORED report (#980).
- [[pudu-ios-device]] — device facts, network reachability and keep-awake on the iOS host, with the DESCRIBED and NETWORKED reports (#983).
- [[pudu-ios-location]] — device location on the iOS host, with the LOCATED report and the self-test (#986).
- [[pudu-ios-tabs]] — UIKit tab bar: a stack per tab, bar items, tab picks, the sheet and self-test (#977).
- [[pudu-ios-values]] — UIKit value controls, their BOUNDS, OPTIONS, COUNT and MOMENT handlers, and their self-test (#934).
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

[[src/_MOC]] · [[Foreign Call]] · [[ADR-0018 Calling a Library Written Elsewhere]]- [[pudu-ios-permission]] — iOS permission state mapping, requests, settings and foreground re-checks (#976).
