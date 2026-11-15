---
type: module
path: "@root/examples/mobile/Feed.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native]
aliases: [Native Feed Example]
---

# Native Feed Example

## Purpose and interface

A root `Scroll` contains a column of 40 numbered labels and a named text field at the end. The
entry mounts the screen, applies its stream, and waits until the platform reports `Stopped`. The
entry then returns 0. The field uses the normal UIKit focus path through [[iOS Host Adapter]].

## Invariants

The field begins below the initial viewport. Focusing it exercises both viewport resizing and
scrolling the field into view. The labels report every row in original order.

## Negative Logic

Platform access goes through [[Std Mobile Host]]. The example keeps all rows mounted.

## Dependencies and consumers

[[Std Mobile View]] constructs the view. [[iOS Simulator Run]] checks geometry, focus and output.

## Resolved Grill Log

- **Q:** Why place the field last? **A:** A field already visible could pass without any
  reveal behavior. A field below 40 rows must be scrolled into view.

## Referenced by

[[src/examples/README]] · [[Native iOS Scrolling Delivery]]
