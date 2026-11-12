---
type: module
path: "@root/test/desktop-storage.ps1"
fidelity: Active
aliases: [Desktop Storage Gate]
tags: [module, test, desktop, windows, isolation]
---
# Desktop Storage Gate

## Purpose and interface

Accept the built native storage harness path. Generate a fresh nonce and task-owned local-data
root, invoke write and read phases in separate processes, retain their output logs and assert
phase-specific completion markers. Temporarily set LOCALAPPDATA for child admission only and
restore the previous value in finally.

## Resolved Grill Log

- **Q:** What separates process reopening from browser memory reuse? **A:** Between phases,
  enumerate real WebView2 browser processes and wait until no command line references the unique
  task data root. Enumeration failure, any unavailable browser command line or timeout fails the gate; no browser
  process is killed.
- **Q:** What may cleanup remove? **A:** Only the newly generated root, after its browser processes
  have exited. Preserve diagnostic data if browsers remain active. Original failures stay failures;
  cleanup failure also fails an otherwise successful gate.
- **Q:** Can a stale result pass? **A:** The nonce names a fresh store and the write page requires
  it to be empty before writing. Each phase has a distinct required output marker.

## Dependencies and consumers

Uses [[Webview Storage Harness]] and PowerShell on the Windows CI runner. Called by
[[Desktop Webview CI]]. No host browser state, profile, trust store or signing configuration changes.

## Referenced by

[[src/_MOC]] · [[Webview Storage Harness]] · [[Desktop Webview CI]]

Resolved Grill Log: parse the two actual private profile names from the successful write output,
validate their bounded identifier form and pass them to the read process in task-specific
environment variables. Restore those variables in finally. Read requires six validated views,
including the persistent replays of both old private profiles.
