---
type: module
path: "@root/test-fixtures/desktop/ApplicationIsolation.pudu"
fidelity: Active
aliases: [Desktop Application Isolation Fixture]
tags: [module, test, desktop, isolation]
---
# Desktop Application Isolation Fixture

## Purpose and interface

Run two distinctly named applications sequentially in one process, both using the default `main`
view label. The first writes a fresh local-storage marker; the second must not see that marker.
Both report their result through typed IPC and close their window before the next application runs.
Reopening the writer without writing must retain its marker. Failure exits with status one.
A second pair uses delimiter-bearing application/view names to
exclude concatenation collisions. A final completion line proves all run loops returned.

## Grill Log

- **Q:** Why use actual applications? **A:** A native-context unit test cannot detect a shared label
  produced by App itself. This crosses the producer, native context, page storage and IPC boundaries.
- **Q:** Can old persisted content satisfy the check? **A:** The writer stores a fresh random marker;
  the reader compares that exact random marker, passed only in its test script. The first application
  verifies its write before reporting success.

## Dependencies and consumers

Uses [[Std Desktop App]], [[Std Desktop Capability]], [[Std Desktop Ipc]], [[Std Desktop Protocol]],
[[Std Desktop Shape]] and [[Std Json]]. Consumed by [[Desktop Webview Gate]] and [[Desktop Webview CI]].

## Referenced by

[[src/_MOC]] · [[Std Desktop App]] · [[Desktop Webview Gate]] · [[Desktop Webview CI]]
