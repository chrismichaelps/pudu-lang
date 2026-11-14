---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_layout.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Layout]
---

# iOS Host Layout

## Purpose and interface

Private UIKit layout implementation included once by [[iOS Host Adapter]]. The compiler stages it
alongside the host translation unit. It owns the scroll view factory and stack accessor,
the available root area, root placement, and field reveal.

## Invariants

- The available area shares the safe area's top and horizontal edges. Its bottom is the safe
  bottom or the top edge of the docked keyboard, whichever is higher on screen. Create the guide
  after the window becomes key and visible so it can observe keyboard changes.
- A scroll root fills that area. Ordinary roots are centered and constrained by its edges.
- A vertical scroll view fixes its content width to its viewport. Its content height follows
  its child and can exceed the viewport.
- The nearest viewport reveals a focused field when editing begins and after the viewport
  changes size. The field reference is weak and reveal requires that it still owns focus.

## Negative Logic

The implementation exposes no new foreign symbols. It uses the docked keyboard layout guide
and does not change the view stream or synthesize input events.

## Dependencies and consumers

Depends on UIKit. Consumed by [[iOS Host Adapter]] and staged by [[Backend Toolchain App]].

## Resolved Grill Log

- **Q:** Adjust the window from keyboard notifications? **A:** The platform layout guide
  supplies geometry in the surface's coordinate space. The scroll view responds to size changes
  and uses normal focus for reveal.
- **Q:** Add a separate host translation unit? **A:** The private header keeps layout independent
  of the stream decoder and preserves the existing one-source clang invocation.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Native iOS Scrolling Delivery]]
