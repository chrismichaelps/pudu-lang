---
type: module
path: "@root/cbits/pudu_webview_win_control.cpp"
fidelity: Active
aliases: [Pudu Webview Windows Control]
tags: [module, runtime, desktop, windows]
---
# Pudu Webview Windows Control

## Purpose and interface

Window chrome and state beyond opening and sizing on Win32, for the same records
[[Pudu Webview macOS Window]] and [[Pudu Webview GTK Window]] answer: `minimize`, `unminimize`,
`maximize`, `unmaximize`, `toggle-maximize`, `always-on-top`, `decorations`, `closable`,
`minimizable`, `maximizable`, `resizable`, `content-protected`, `background`, `titlebar`,
`attention`, `badge` and `state`; true fullscreen over the window's monitor; and the
`window-state`, `scale` and `theme` events. [[Pudu Webview Windows Adapter]] routes every window
verb it does not own to `pudu_window_extra` and forwards state, DPI, theme and erase messages.

## Semantics

- Requested chrome is kept as flags and the native style is derived from them, so turning one
  flag back on restores exactly what the others allow. Without decorations the window has no
  caption, system menu or sizing frame; `titlebar overlay` drops only the caption and keeps the
  sizing frame so content can reach the top edge.
- `closable 0` greys the system menu's close command; the close request still reaches the program
  as `close-requested`, which decides.
- `content-protected` excludes the window from capture, falling back to the older monitor-only
  affinity; a system with neither refuses `Unsupported`, and clearing answers the same way.
- `fullscreen 1` remembers the window's placement, removes its chrome and covers the monitor;
  size limits do not apply while it is fullscreen, and chrome records change the remembered
  flags without restyling. `fullscreen 0` restores the chrome and the placement.
- `background r g b a` paints the client area behind views with an owned brush released when the
  window closes; Win32 has no per-window alpha for the client area, so alpha is validated and
  not applied.
- `attention critical` flashes until the window is in front; `informational` flashes the taskbar
  button three times.
- `window-state <id> <minimized> <maximized> <fullscreen> <visible> <focused>` and
  `scale <id> <thousandths>` are recorded together whenever either differs from the last record,
  and always on `state`, which also records `moved`, `resized` and `theme`.
- `titlebar transparent` and `badge` refuse `Unsupported`: Win32 offers neither without an
  application-supplied overlay icon or a custom-drawn frame.

## Grill Log

- **Q:** Can `fullscreen` stay a maximize? **A:** No. A maximized window keeps its caption and
  taskbar; the record means covering the monitor, as on the other platforms.
- **Q:** Call `SetWindowDisplayAffinity` directly? **A:** No. It is found at run time, so headers
  that predate it still build; a missing entry point answers `Unsupported`.
- **Q:** Report state from every message? **A:** No. The last record is remembered and a message
  that changes nothing records nothing, so programs are not flooded on every move.

## Dependencies and consumers

Uses [[Pudu Webview Windows Host]]. Called by [[Pudu Webview Windows Adapter]] and verified by
[[Webview Windows Window Harness]]. Registered by [[Pudu Cabal Manifest]] and [[Desktop Webview CI]].

## Referenced by

[[src/cbits/_MOC]] · [[Pudu Webview Windows Adapter]] · [[Pudu Webview Windows Window]] · [[Pudu Webview Windows Host]]
