---
type: module
path: "@root/lib/Std/Desktop/Reload.pudu"
fidelity: Active
aliases: [Std Desktop Reload]
tags: [module, stdlib, desktop, development]
---
# Std Desktop Reload

## Purpose and interface

`snapshot` reads modification times of frontend files. `changed` compares snapshots and builds
style reload records when only CSS changed, or page reloads for every supplied view otherwise.

## Semantics

Identical snapshots do nothing. Added and removed files count as changes. No file reads occur in
`changed`; snapshots omit files whose modification time cannot be read.

## Grill Log

- **Q:** Why separate this from the application loop? **A:** Change classification is pure and
  independently testable; filesystem polling has no window lifecycle responsibility.

## Dependencies and consumers

Uses [[Std Desktop Protocol]], [[Std Desktop Webview]], [[Std Fs]] and [[Std Path]].
Consumed by [[Std Desktop App]] and [[Desktop Modules Fixture]].

## Referenced by

[[src/Std/_MOC]] · [[Std Desktop App]]
