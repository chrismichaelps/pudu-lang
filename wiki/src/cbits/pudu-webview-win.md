---
type: module
path: "@root/cbits/pudu_webview_win.cpp"
fidelity: Active
tags: [module, runtime, desktop, webview, windows]
aliases: [Pudu Webview Windows Adapter]
---

# Pudu Webview Windows Adapter

## Purpose and interface

Implements [[Pudu Webview Header]] on Windows: Win32 windows, the message pump, the event queue,
request bodies and responses. Views come from [[Pudu Webview Windows View]]; shared declarations,
including the COM handler template, from [[Pudu Webview Windows Host]].

## Semantics

- The first call initializes COM for a single-threaded apartment and registers the window class;
  calls from another thread answer `-2`.
- The close button records `close-requested` and leaves the window open; resizing records `resized`
  and refits filling views; activation records `focused`.
- Size/limit records delegate to [[Pudu Webview Windows Window]], and WM_GETMINMAXINFO supplies
  retained menu/style-aware limits. Opening rejects nonboolean flags and dimensions that cannot
  fit native coordinates before creating a window.
- The pump dispatches messages until an event is queued or the slice ends, waiting in
  `MsgWaitForMultipleObjectsEx`; queuing posts a thread message that ends the wait.
- A response completes the request's deferral with a response built from the program's status and
  its standard reason phrase, headers (line breaks converted to CRLF) and body. The body is held in a
  global-memory stream: a deferred response is read after the handler returned, possibly from
  another thread, which a plain memory stream does not support.

## Grill Log

- **Q:** Where do view lookup and released COM strings live after extraction? **A:** Shared private
  utilities remain beside the process host, used by view, environment and request translation units.

- **Q:** Link the WebView2 loader or load it? **A:** Load `WebView2Loader.dll` at run time. Its
  import library is built for one toolchain; loading it keeps the adapter linkable by any compiler and
  turns a missing loader into a typed `unsupported` refusal instead of a start-up failure.
- **Q:** May min/max records succeed without enforcement? **A:** No. Native commands and tracking
  share retained bounds, and invalid updates preserve the previous limits.

## Dependencies and consumers

Uses [[Pudu Webview Records]]. Called by [[Eval Webview]] when built with the `webview2` flag; driven
in CI by [[Webview Drive Harness]].

## Referenced by

[[src/cbits/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]

Resolved Grill Log: response header/body slices share the ABI rule: NULL only for zero length, otherwise Invalid.

Resolved Grill Log: WM_SIZING and WM_WINDOWPOSCHANGING delegate to width-aware client-bound enforcement. Default position processing runs first; the final candidate handles menu wrapping at the new width.

Resolved Grill Log: lifetime lookup checks both identity and liveness. Window teardown invalidates
all affected view callbacks before controller Close can synchronously reenter. Numeric command
lookup remains separate from asynchronous callback admission.

Resolved Grill Log: erase registry membership while moving ownership into a local owner before
native teardown. Reentrant close/recreate must not invalidate an active iterator, delete the
teardown owner, or erase a replacement id. Capture failure diagnostic labels before native Close
and recheck callback identity before later publication when the descriptor may be replaced.

Resolved Grill Log: detach the closing window owner as well as its old views before calling native
Close. A reentrant create cannot attach to that closing window; a replacement window with the same
id is independently owned and survives completion of the old teardown.

Resolved Grill Log: clear the closing HWND owner pointer before invoking any native controller
Close. Late window messages cannot emit events or refit views belonging to a reused window id.

## Closing releases what a view owns

Resolved Grill Log: `pudu_close_view` invalidates the lifetime token, then detaches and finishes
every pending request of that lifetime, then calls native controller Close, then releases the
renderer, controller and environment references it owns, each exactly once and nulled before
release so a reentrant close finds nothing left to release. A view already closed by policy
failure still releases its references when its descriptor is removed. `pudu_webview_respond`
detaches the record before any native call and answers with the record's own environment, never
another view's; after the originating view closed, the record no longer exists and the answer is
Gone. A request whose response cannot be built is still completed and released.

Resolved Grill Log: a window verb the adapter does not own goes to [[Pudu Webview Windows Control]]
instead of refusing, and `fullscreen` covers the monitor there rather than maximizing. The window
procedure forwards visibility, DPI, theme and background-erase messages to the same unit, which
records `window-state`, `scale` and `theme` and releases the window's background brush on close.
