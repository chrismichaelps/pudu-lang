---
type: module
path: "@root/test/native/WebviewStorageWin.cpp"
fidelity: Active
aliases: [Webview Windows Storage Probe]
tags: [module, test, desktop, windows, isolation]
---
# Webview Windows Storage Probe

## Purpose and interface

Test-only native observations complement [[Webview Storage Harness]]. `pudu_storage_mode` queries
the actual renderer's Profile interface, requires the expected IsInPrivateModeEnabled flag and
reports the generated profile name for private views. No production API is extended.

`pudu_storage_replay` attaches a previously created harness descriptor to a persistent controller
with the exact prior private profile name, in the same private-data folder. It uses the real native
options and production controller callback, so the page loads through ordinary request handling.
The second process must not find the sentinel written by the earlier private session. A backend
that accidentally writes persistent data under changing private profile names can no longer pass
by creating another fresh name.

## Resolved Grill Log

- **Q:** Why reach into native internals in a test? **A:** Fresh-session emptiness cannot establish
  private mode or absence of persisted data. Observe the actual SDK mode and deliberately reopen
  the old profile as non-private; this test-only forensic path must not become a public option.
- **Q:** Who owns native references? **A:** Query/profile/options references are released locally.
  The replay descriptor retains its environment and production callback owns its controller;
  ordinary harness window cleanup releases them. The completion keeps lifetime identity checks.

- **Q:** How is browser exit attributed to this test? **A:** Read the process ID from each
  live view and retain a wait-only handle before closing it. A shared deadline bounds the wait
  across all handles, and native messages continue to dispatch during teardown. Handle capture
  and wait failures fail the phase. Close every acquired handle on success and failure.

## Dependencies and consumers

Uses [[Pudu Webview Windows Host]], actual SDK Profile/Environment10 interfaces and
[[Pudu Webview Windows View]]. Linked only into [[Webview Storage Harness]] on Windows by
[[Desktop Webview CI]].

## Referenced by

[[src/_MOC]] · [[Webview Storage Harness]] · [[Desktop Storage Gate]] · [[Desktop Webview CI]]

Resolved Grill Log: forensic replay also compares the controller's observed ProfileName with the
requested prior identity. Setter success alone cannot establish which profile was reopened.
