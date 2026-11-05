---
type: module
path: "@root/cbits/pudu_webview_win_view.cpp"
fidelity: Active
tags: [module, runtime, desktop, webview, windows]
aliases: [Pudu Webview Windows View]
---

# Pudu Webview Windows View

## Purpose and interface

One WebView2 view: collected configuration, an environment that registers `pudu` as a secure
scheme with an authority, a controller, and the request, navigation, window, title, process and
script handlers that turn WebView2 into the record channel.

## Semantics

- Each view's storage is `%LOCALAPPDATA%\<program>\webview\<digest of label>`; `ephemeral` uses
  InPrivate mode where the runtime offers it.
- Commands sent after `realize` but before the controller exists are queued and applied in order
  once it does; the initial page loads after scripts and rules are in place.
- Inline HTML is served from `pudu://app/.pudu/inline/<view>-<n>`, so it has the application's
  origin as on the other platforms.
- Content rules are enforced by the request filter: `block` answers `403`, `block-cookies` removes
  the cookie header, `make-https` redirects, and `css-display-none` injects a hiding style. A rule
  the adapter cannot enforce — an action it does not know or an expression that does not compile —
  is refused when configured, so a view never runs with a rule silently dropped.
- Scripts limited to the main frame are wrapped to run only in the top window; scripts for the end
  of parsing wait for `DOMContentLoaded`.
- `devtools-open` opens the inspector window; `devtools-close` answers `-7`, since the platform
  offers no call to close it.

## Grill Log

- **Q:** The platform has no declarative content blocker; drop rules or emulate them? **A:**
  Emulate them in the request filter, which runs before a request leaves the view; dropping them would
  give a plugin the appearance of protection without the substance.

## Dependencies and consumers

Uses [[Pudu Webview Records]] and [[Pudu Webview Windows Host]]; driven by
[[Pudu Webview Windows Adapter]].

## Referenced by

[[src/cbits/_MOC]]
