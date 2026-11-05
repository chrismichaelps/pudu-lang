---
type: module
path: "@root/cbits/pudu_webview_macos_view.m"
fidelity: Active
tags: [module, runtime, desktop, webview, macos]
aliases: [Pudu Webview macOS View]
---

# Pudu Webview macOS View

## Purpose and interface

One WebView on macOS: collects configuration records, realizes the WebView with them, applies
commands, serves the `pudu` URL scheme by turning each request into an event, enforces the
navigation allowlist, compiles content-blocking rules, and reports loads, titles, crashes and script
results.

## Semantics

- Configuration (`url`, `html`, `devtools`, `user-agent`, `zoom`, `data-store`, `ephemeral`,
  `navigation-allow`, `script`, `style`, `rules`, `transparent`) is accepted only before `realize`;
  after it, configuration records are refused with `-3` so a script added late cannot silently miss
  pages already loaded.
- The data store is ephemeral, named by the label (`dataStoreForIdentifier`, where the system
  offers it) or, on systems without named stores, the default store; the fallback is reported as a
  `data-store` event with `shared` so the program knows isolation is weaker.
- Navigation to the `pudu` scheme, `about:` and `data:` is allowed; any other URL must match a
  `navigation-allow` pattern. A refused navigation is cancelled and reported. A request for a new
  window is refused and reported.
- `devtools` sets the WebView inspectable and enables developer extras; `devtools-open` shows the
  inspector when the system exposes it and answers `-7` otherwise.
- `rules` compile asynchronously; the list is attached when compilation finishes and `rules ready`
  or `rules failed` is reported.
- `eval` reports the script's value as text: a string as itself, nothing as `null`, any other value
  as JSON.
- Styles are injected as a document-start script that appends a `style` element when the document
  element exists, so they apply before first paint.

## Grill Log

- **Q:** Why must styles go through a script? **A:** The platform's user style sheet API is newer
  than the oldest supported system; a script at document start gives the same timing everywhere.
- **Q:** Why answer `-7` for `devtools-open` instead of pretending? **A:** Opening the inspector
  programmatically uses an interface the system does not promise; the inspector itself stays
  reachable from the context menu, and a silent success would hide the difference.

## Dependencies and consumers

Uses [[Pudu Webview Records]] and [[Pudu Webview macOS Host]]; driven by
[[Pudu Webview macOS Adapter]].

## Referenced by

[[src/cbits/_MOC]]
