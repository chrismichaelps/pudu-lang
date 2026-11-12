---
type: module
path: "@root/cbits/pudu_webview_win_window.cpp"
fidelity: Active
aliases: [Pudu Webview Windows Window]
tags: [module, runtime, desktop, windows]
---
# Pudu Webview Windows Window

## Purpose and interface

Own Win32 client-size conversion and persistent minimum/maximum window limits. Private helpers
convert client dimensions to outer dimensions, apply a size or limit command, and fill native
MINMAXINFO tracking/maximize bounds. [[Pudu Webview Windows Adapter]] routes records and messages.

## Semantics

Dimensions must fit Win32 signed coordinates after accounting for actual styles and menu chrome.
Sizes must be positive; each zero limit removes that axis's bound. Negative, overflowing or
contradictory limits answer Invalid without mutating previous limits. Setting a limit clamps the
current client size; later explicit sizes and interactive tracking respect the same bounds. The
other bound is retained when either minimum or maximum changes. Native conversion uses the actual
menu, normal style and extended style. Native failures answer Platform.

Native menu wrapping is measured through WM_NCCALCSIZE at the proposed width, since
AdjustWindowRectEx only reserves one menu row. The conversion keeps the extra height in checked
wide arithmetic. The wrapped-menu regression must fail before compensation is enabled.

## Grill Log

- **Q:** Can success leave enforcement to application resize handling? **A:** No. Persist native
  constraints, clamp programmatic sizes and supply outer dimensions through WM_GETMINMAXINFO.
- **Q:** Why convert zero client dimensions first? **A:** Measure non-client extents before adding
  caller dimensions in 64-bit arithmetic, preventing oversized input from wrapping a Win32 RECT.
- **Q:** Do geometry tests need a running page? **A:** No. The dedicated harness drives the
  production adapter and measures actual window bounds, including menu conversion and refusal.
- **Q:** Does a fixed menu-row metric preserve client size? **A:** No. Query the actual menu
  layout at the proposed width before sizing the native frame.

## Dependencies and consumers

Uses [[Pudu Webview Windows Host]]. Called by [[Pudu Webview Windows Adapter]] and verified by
[[Webview Windows Window Harness]]. Registered by [[Pudu Cabal Manifest]] and [[Desktop Webview CI]].

## Referenced by

[[src/cbits/_MOC]] · [[Pudu Webview Windows Adapter]] · [[Pudu Webview Windows Host]] · [[Pudu Webview Windows Control]]

## Native layout enforcement

Resolved Grill Log: a shared outer-size clamp converts to client dimensions, clamps width, then
recomputes menu wrapping at that width before clamping height. WM_SIZING preserves the opposite
dragged edge. WM_WINDOWPOSCHANGING runs default processing first, then adjusts WINDOWPOS without
recursively setting position; pure moves and iconification are excluded. Frame changes reapply
constraints even with SWP_NOSIZE. Menu tracking uses conservative vertical minima and leaves
vertical maxima to the final clamp: independent hints cannot encode width-dependent wrapping.
An owner guard prevents recursive layout while native queries execute.

Resolved Grill Log: while a window is fullscreen ([[Pudu Webview Windows Control]]) neither the
tracking limits nor the position clamp apply; the limits return with the restored placement.
