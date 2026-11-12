---
type: module
path: "@root/test/desktop-policy-https.sh"
fidelity: Active
aliases: [Desktop Policy HTTPS Gate]
tags: [module, test, desktop, tls]
---
# Desktop Policy HTTPS Gate

## Purpose and interface

Run successful native HTTPS-upgrade conformance in an isolated Linux root test environment. Generate
a fresh one-day loopback test certificate, add only that certificate to the task container/CI trust
store, run the real network gate under a virtual display and remove the test certificate/key/trust
entry on exit. The native executable is the only argument. No host trust store is changed.

## Grill Log

- **Q:** Why use real trust instead of disabling certificate verification? **A:** The native request
  must complete normal certificate validation; a successful body echo then proves secure delivery.
- **Q:** Which machines may run this wrapper? **A:** Only a container or CI Linux root environment,
  with an explicit test-trust flag. Regular native network checks remain unprivileged.
- **Q:** What survives the run? **A:** Only validation logs; fresh trust files and private keys are
  removed by an exit trap. Process sandbox disabling is specific to this root-owned test run.

## Dependencies and consumers

Uses OpenSSL, the Linux certificate update command, Node and a virtual display. Runs
[[Desktop Policy Network Gate]] and [[Webview Network Policy Harness]]. Registered by
[[Desktop Webview CI]].

## Referenced by

[[src/_MOC]] · [[Desktop Webview CI]] · [[Desktop Policy Network Gate]]

Resolved Grill Log: cleanup must run every step, preserve an earlier test failure, and turn a successful test into failure when trust removal/rehash cannot be proved. Verify that the generated certificate no longer validates against the rebuilt aggregate CA bundle before deleting its temporary files.
