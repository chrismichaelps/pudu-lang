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
- [[Pudu Webview Header]] — the six-entry WebView record channel and its statuses.
- [[Pudu Webview Records]] — length-prefixed record framing and bounded URL patterns.
- [[Pudu Webview macOS Host]] · [[Pudu Webview macOS Adapter]] · [[Pudu Webview macOS View]] — WebKit windows, views, scheme requests and policy.
- [[Pudu Webview macOS Native]] — menu bar, dialogs and native surfaces in a WebView window.
- [[Pudu Webview GTK Adapter]] · [[Pudu Webview GTK Native]] — the same contract and components on WebKitGTK.
- [[Pudu Webview Windows Host]] · [[Pudu Webview Windows Adapter]] · [[Pudu Webview Windows View]] · [[Pudu Webview Windows Native]] — the same contract and components on WebView2, with lifetime-scoped callback admission.
- [[Pudu Audio Header]] — framework-neutral bounded device-playback ABI and stable statuses.
- [[Pudu Audio Adapter]] — macOS Audio Queue ownership, preallocation, refill, deadline, and release.
- [[Pudu Audio Stream Header]] — framework-neutral persistent-output ABI, snapshot layout, and stable statuses.
- [[Pudu Audio Stream Adapter]] — macOS persistent Audio Queue sessions, bounded writes, controls,
  hardware timeline, telemetry, and release.

- [[Desktop Presentation Test]] · [[Desktop Presentation Gate]] — native presentation orientation regression.


- [[Pudu Webview macOS Window]] — window controls, state and permitted drag regions.

- [[Pudu Webview GTK Host]] · [[Pudu Webview GTK Context]] · [[Pudu Webview GTK View]] · [[Pudu Webview GTK Window]] · [[Pudu Webview GTK Interaction]] — native state, controls and authenticated interaction.

- [[Pudu Webview Windows Window]] — retained native geometry and size constraints.
- [[Pudu Webview Windows Control]] — window chrome, state, fullscreen and state events.
- [[Pudu Webview Windows Profile]] — verified named-store folders and private per-view profiles; [[Webview Storage Harness]] checks actual persistence.
- [[Pudu Webview Windows Environment]] · [[Pudu Webview Windows Request]] — environment creation,
  scheme/profile configuration and request/navigation policy.

## Referenced by

[[src/_MOC]] · [[Foreign Call]] · [[ADR-0018 Calling a Library Written Elsewhere]]

- [[Pudu Webview Policy JSON Header]] · [[Pudu Webview Policy JSON]] · [[Pudu Webview Windows Policy]] — structural JSON and complete compiled rule admission.

- [[Pudu Webview Windows SDK]] — scoped compiler-aware COM interface UUID metadata.
