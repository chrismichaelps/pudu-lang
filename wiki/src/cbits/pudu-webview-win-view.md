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

Environment creation delegates to [[Pudu Webview Windows Environment]]. Resource and navigation
policy delegates to [[Pudu Webview Windows Request]]. This unit retains command collection,
controller registration, deferred startup, script readiness and live view operations.

## Semantics

- Each view's storage is `%LOCALAPPDATA%\<program>\webview\<digest of label>`; `ephemeral` uses
  InPrivate mode where the runtime offers it.
- Commands sent after `realize` but before the controller exists are queued and applied in order
  once the first page has started; that page loads only after every document-creation script
  finished registering, so no script misses it.
- Inline HTML is served from `pudu://app/.pudu/inline/<view>-<n>`, so it has the application's
  origin as on the other platforms.
- Content rules are enforced by the request filter: `block` answers `403`, `block-cookies` attempts an empty Cookie override,
  `make-https` mutates the native URI, and `css-display-none` injects a hiding style. A rule
  the adapter cannot enforce — an action it does not know or an expression that does not compile —
  is refused when configured, so a view never runs with a rule silently dropped.
- Navigations of the page and of every frame pass the same allowlist; the `pudu` scheme admits
  calls only from the application's origin and the scheme and authority of each allowed pattern.
- Callbacks require the captured lifetime identity as well as the numeric id; closed or replaced views cannot receive late events.
- Scripts limited to the main frame are wrapped to run only in the top window; scripts for the end
  of parsing wait for `DOMContentLoaded`.
- `devtools-open` opens the inspector window; `devtools-close` answers `-7`, since the platform
  offers no call to close it.

## Grill Log

- **Q:** The platform has no declarative content blocker; drop rules or emulate them? **A:**
  Emulate them in the request filter, which runs before a request leaves the view; dropping them would
  give a plugin the appearance of protection without the substance.
- **Q:** Where are configuration COM objects owned? **A:** [[Pudu Webview Windows Environment]]
  owns their concrete types and native creation call; this unit owns controller setup and startup.
- **Q:** Why split the view module before extending it? **A:** Environment configuration and
  resource policy are independently owned phase boundaries. Move their bodies unchanged while
  preserving script readiness, callback ownership and deferred-command ordering in this unit.

## Dependencies and consumers

Resolved Grill Log: inline and named callback registrations use the scoped creation owner returned
by pudu_handler; WebView's retained reference owns asynchronous lifetime after registration.

Uses [[Pudu Webview Records]] and [[Pudu Webview Windows Host]]; driven by
[[Pudu Webview Windows Adapter]].

## Referenced by

[[src/cbits/_MOC]]

Resolved Grill Log: rule installation returns the policy layer status without partial mutation. Hide-element scripts come from the compiled policy guard; JSON eval strings use structural Unicode decoding rather than the old substring decoder.

Resolved Grill Log: top/frame navigation callbacks are distinguished for domain attribution. Guarded CSS is emitted by the policy compiler. Native eval JSON strings use bounded structural decoding and report decoding failures as eval errors.

Resolved Grill Log: append one generated style-policy closure for the complete CSS rule set, so individual registrations cannot reset the document work budget.

Resolved Grill Log: all interface queries use the production SDK UUID helper; startup and controller behavior are unchanged.

Resolved Grill Log: all asynchronous completions/events capture a lifetime reference, including
script readiness and eval replies. A stale callback neither mutates a reused id nor publishes its
events; navigation still cancels stale requests and new-window requests remain handled. Close is
immediate even during realization, invalidates before native teardown, and closed policy-failed
views refuse later commands except close. Production completion factories permit deterministic
late-completion tests without a renderer.

Resolved Grill Log: erase registry membership while moving ownership into a local owner before
native teardown. Reentrant close/recreate must not invalidate an active iterator, delete the
teardown owner, or erase a replacement id. Capture failure diagnostic labels before native Close
and recheck callback identity before later publication when the descriptor may be replaced.

## Fail-closed realization

Resolved Grill Log: the environment completion delegates controller creation to
[[Pudu Webview Windows Environment]] admission and never chooses ordinary creation for a private
view itself. A failed or empty environment completion, a failed controller completion and every
refused admission step report `refused` and close the view rather than reporting `crashed`: an
application that reloads a crashed view must not retry a view that was never admitted. `crashed`
remains the renderer-process failure of an admitted view. The owned environment, controller and
renderer references are released by the shared close path in [[Pudu Webview Windows Adapter]].
