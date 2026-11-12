---
type: module
path: "@root/test-fixtures/desktop/WindowLoop.pudu"
fidelity: Active
aliases: [Desktop Window Loop Fixture]
tags: [module, test, desktop]
---
# Desktop Window Loop Fixture

## Purpose and interface

Run two windows with packed HTML and JavaScript assets. Each page queries native state, changes its
title, proves hide is denied and malformed close values are refused, reports a checkpoint, and asks
to close. The application prints completion only after both windows close through IPC.

## Grill Log

- **Q:** Why test through real pages rather than call Chrome directly? **A:** This catches discarded
  Loop updates, unobserved native events and response/teardown ordering across the actual bridge.

## Dependencies and consumers

Uses [[Std Desktop App]], [[Std Desktop Capability]], [[Std Desktop Ipc]], [[Std Desktop Shape]],
[[Std Desktop Protocol]]. Consumed by [[Desktop Webview Gate]].

## Referenced by

[[Desktop Webview Gate]] · [[Std Desktop App]]
