---
type: module
path: "@root/cbits/pudu_desktop_window.m"
fidelity: Active
tags: [module, runtime, ui, macos]
aliases: [Pudu Desktop Window]
---

# Pudu Desktop Window

## Purpose and interface

The window-state half of [[Pudu Desktop Adapter]]: a `WindowState` category on the window host
that records `scale`, `focus`, `minimize` and `fullscreen` transitions the platform makes on its
own, and `pudu_desktop_configure`, which applies the caller's density, content size limits,
aspect ratio and full-screen request. `recordScale` reports the backing scale times one thousand
only when it differs from the last report, so a backing-property notification that changes
nothing adds no record.

## Invariants

- Configure validates every argument before touching the window and fails off the main thread.
- Content limits are in points; zero maximum means unlimited and zero aspect clears the ratio.
- Full screen toggles only when the request differs from the window's current state; the
  transition is reported by its record when it completes.

## Grill Log

- **Q:** Keep these in the main adapter file? **A:** No; the adapter would pass 500 lines and mix
  presentation with window policy. The category shares the host's queue and density.

## Referenced by

[[cbits/_MOC]] · [[Pudu Desktop Adapter]] · [[Desktop Window Test]]
