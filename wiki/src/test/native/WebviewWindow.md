---
type: module
path: "@root/test/native/WebviewWindow.cpp"
fidelity: Active
aliases: [Webview Windows Window Harness]
tags: [module, test, desktop, windows]
---
# Webview Windows Window Harness

## Purpose and interface

Drive the production Windows record adapter against a real window without creating a renderer.
Also exercise the production asynchronous completion factories against closed/reused view identities.
Check min/max client sizes, immediate clamping, later resizing, WM_GETMINMAXINFO outer bounds,
axis reset, retained opposite bounds and real menu conversion. Negative, zero-size, overflow and
contradictory records must refuse and preserve prior geometry/constraints. Close through the ABI
and require native destruction. Any failed assertion exits with a diagnostic.

Attach enough menu items to wrap at a narrow width and measure the real client size; a single
short item cannot prove menu-aware sizing. Change width while limits remain active to catch
stale wrapping metrics. Check bounded native maximization and restoration too.

Resolved Grill Log: send sizing messages for all four corners and verify the opposite edge stays
fixed, then apply their proposed frames to the real window. Direct SetWindowPos and frame-change
paths must also retain client bounds; minimizing must still produce an iconified window.

## Grill Log

- **Q:** Why a separate harness? **A:** It runs before renderer loading and isolates native geometry;
  [[Webview Drive Harness]] retains page/protocol integration coverage.
- **Q:** Is inspecting stored constraints sufficient? **A:** No. Measure GetClientRect after
  commands and ask the actual window procedure for tracking bounds, including with a menu.

## Dependencies and consumers

Uses [[Pudu Webview Header]], [[Pudu Webview Records]] and the complete Windows adapter.
Run by [[Desktop Webview CI]].

## Referenced by

[[src/_MOC]] · [[Desktop Webview CI]] · [[Pudu Webview Windows Window]]

Resolved Grill Log: extend the complete-adapter harness with callback lifetime checks before the
geometry checks. Use actual production environment/controller completion factories, a conforming
SDK controller double and reused view ids. Verify stale failure emits no event, a late borrowed
controller is closed once without Release, retained old tokens cannot authorize replacements,
current failure still emits its diagnostic and realization-time close cancels callbacks.

Resolved Grill Log: the native Close double reenters the actual command path and recreates the
same id. The outer close must preserve that replacement. Window teardown first detaches all old
views; newly created views cannot be consumed by its old-view traversal.

Resolved Grill Log: after creating a replacement window during Close, drain its legitimate startup
events and send size/move/activate messages to the old HWND; no old-window events may escape.

Resolved Grill Log: a failed environment completion for the current view now expects
`refused <view> platform <reason>` rather than `crashed <view>`; admission failure is not a
renderer crash. The stale-token cases are unchanged and still publish nothing.

Resolved Grill Log: after the geometry checks, drive every chrome and state record through the
production adapter and inspect the real window: styles for chrome flags and title bars, the
system menu for `closable`, `WS_EX_TOPMOST`, zoom and iconic state, a fullscreen frame equal to
the monitor that restores the earlier frame exactly, and the `window-state`, `scale`, `theme`,
`moved` and `resized` records of `state`. Malformed values, unknown verbs, a transparent title
bar and a badge must refuse. The harness prints `window-controls=1`.
