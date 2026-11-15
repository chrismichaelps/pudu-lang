---
type: module
path: "@root/examples/mobile/Pages.pudu"
fidelity: Active
tags: [module, example, mobile, native]
aliases: [Native Pages Example]
---

# Native Pages Example

## Purpose and interface

Mount a root page and a detail page with the [[Std Mobile Navigation]] API.
Consume a completed native back action, apply it to the route model, and commit
the resulting root stack. The simulator checks the reported source and destination
IDs and confirms the root page is visible afterward. A separate run taps a detail-page button,
which submits a Pudu-owned pop and fails if it receives any native pop event.

## Invariants

The mounted state is carried alongside the route model and updated only after an
accepted change. The root identity survives a back action.

## Resolved Grill Log

- **Q:** Why start with a detail page? **A:** The simulator can check the native
  delegate, event bridge, and accepted model change without coordinating a push timer.

## Referenced by

[[iOS Simulator Run]] · [[Native iOS Navigation Delivery]]
