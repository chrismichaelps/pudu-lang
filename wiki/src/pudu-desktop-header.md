---
type: module
path: "@root/cbits/pudu_desktop.h"
fidelity: Active
tags: [module, runtime, ui, macos]
aliases: [Pudu Desktop Header]
---

# Pudu Desktop Header

## Purpose and interface

Declare the private C-compatible ABI between [[Eval Desktop]] and [[Pudu Desktop Adapter]]. The ABI
opens and closes an opaque host pointer, replaces its owned RGBA frame, and pumps events for a
bounded number of milliseconds. It also replaces a window's accessibility snapshot and reports
what the platform exposes for it ([[Pudu Desktop Access]]), and installs and reports the
application's menu bar ([[Pudu Desktop Menu]]). Integer statuses are translated immediately by the Haskell owner;
they are not public Pudu values.

## Grill Log

- **Q:** Put AppKit declarations in the header? **A:** No. _Rationale:_ the Haskell compiler and
  non-macOS targets need a framework-neutral seam. _Rejected:_ Objective-C types in the runtime ABI.
- **Q:** Expose this ABI through Pudu `foreign` declarations? **A:** No. _Rationale:_ it is compiler
  target plumbing with runtime-owned resources. _Rejected:_ application-managed native pointers.

## Referenced by

[[Eval Desktop]] · [[Pudu Desktop Adapter]] · [[Pudu Desktop Access]] · [[Pudu Desktop Menu]]
