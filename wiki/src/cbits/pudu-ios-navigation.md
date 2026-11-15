---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_navigation.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Navigation]
---

# iOS Host Navigation

## Purpose and interface

Private UIKit stack adapter included once by [[iOS Host Adapter]]. Decode NAVIGATION
into a complete ordered snapshot before changing the native stack. Create page
controllers for newly presented instance IDs and retain the common prefix.
Each page controller places its body with [[iOS Host Layout]].

## Invariants

- An empty snapshot, duplicate identity, duplicate body node, unknown node, or
  invalid title is a stream defect. Decode and validate before publishing the stack.
- The desired snapshot and UIKit retain bodies directly across transitions. Node
  retirement makes numeric IDs reusable without invalidating those retained views.
- If a transition is active, retain the latest snapshot and apply it after the
  coordinator completes. Report a pop only when UIKit's completed stack is a
  strict prefix of the requested stack and there is no newer pending snapshot.
- A completed pop reports the old top and surviving route IDs through the event
  queue. Canceled and programmatic transitions do not produce pop events.

## Page sheet

The adapter stores a desired sheet descriptor and the presented controller.
SHEET updates the descriptor. UIKit page-sheet presentation and dismissal are
serialized against navigation and sheet transitions. A user dismissal reports only
the current instance, after UIKit completes it. Programmatic dismissal and a
superseded callback produce no event. Strong references preserve bodies while
an animation finishes even if the corresponding node IDs are retired.

Resolved Grill Log: present the latest desired sheet after any in-flight
presentation or dismissal completes. The old controller is never used as the
identity of a new presentation.

## Simulator evidence

The self-test exercises the completion predicate with an unchanged stack and an
actual controller pop. A separate test waits for the completed programmatic
transition before stopping, so an echoed pop would be visible to Pudu.

## Dependencies and consumers

Depends on UIKit and the decoder helpers of [[iOS Host Adapter]]. The compiler
embeds the header through [[Native Toolchain Host Sources]].

## Resolved Grill Log

- **Q:** Look up numeric node IDs after a UIKit callback? **A:** Hold strong
  view references in pending snapshots and presented controllers. IDs can
  be reused once a commit retires a node.
- **Q:** Dispatch an event on every delegate completion? **A:** Compare
  controller identity and count against the desired stack. Report only an
  unsuperseded, completed reduction to a prefix.

## Referenced by

[[src/cbits/_MOC]] · [[Native iOS Navigation]] · [[iOS Host Adapter]]
