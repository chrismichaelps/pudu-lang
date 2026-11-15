---
type: module
path: "@root/examples/mobile/Sheets.pudu"
fidelity: Active
tags: [module, example, mobile, native]
aliases: [Native Sheets Example]
---

# Native Sheets Example

## Purpose and interface

Presents a native page sheet above a root route using [[Std Mobile Navigation]].
A button requests dismissal from Pudu. A UIKit dismissal instead delivers the
sheet instance to the reducer. The simulator observes the root after both paths.

## Invariants

Only dismissal of the current sheet changes the model. A Pudu-initiated
dismissal completes without an event echo.

## Dependencies and consumers

Uses [[Std Mobile Host]], [[Std Mobile Navigation]] and [[Std Mobile View]].
Run by [[iOS Simulator Run]].

## Resolved Grill Log

- **Q:** Why exercise two dismissal paths? **A:** They reach the same final
  presentation but differ in who owns the state transition and event.

## Referenced by

[[src/examples/README]] · [[Native iOS Navigation Delivery]]
