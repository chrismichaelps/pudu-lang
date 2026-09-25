---
type: module
path: "@root/cbits/pudu_desktop_host.h"
fidelity: Active
tags: [module, runtime, ui, macos]
aliases: [Pudu Desktop Host]
---

# Pudu Desktop Host

## Purpose and interface

Declare the two Objective-C classes the macOS desktop adapter's translation units share:
`PuduFrameView`, the view that draws the presented frame and holds its accessibility children, and
`PuduWindowHost`, the window delegate an opaque handle points to (window, view, close request, and
input queue). [[Pudu Desktop Adapter]] implements both; [[Pudu Desktop Access]] reads the view
through the host.

## Grill Log

- **Q:** Put these declarations in [[Pudu Desktop Header]]? **A:** No. _Rationale:_ that header is
  the framework-neutral ABI the runtime compiles on every target; AppKit types would break it.
  _Accepted:_ a private header only macOS translation units include.

## Referenced by

[[Pudu Desktop Adapter]] · [[Pudu Desktop Access]] · [[src/cbits/_MOC]]
