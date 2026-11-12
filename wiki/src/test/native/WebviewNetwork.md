---
type: module
path: "@root/test/native/WebviewNetwork.c"
fidelity: Active
aliases: [Webview Network Policy Harness]
tags: [module, test, desktop, network, policy]
---
# Webview Network Policy Harness

## Purpose and interface

Drive a real native page from a loopback HTTP server through the six-entry ABI. Install cookie-blocking and request-blocking rules scoped to raw resources and the main document host. Wait on a monotonic deadline for the page outcome, retaining native failures. The optional upgrade mode adds a Windows nondefault-port URI-upgrade probe; it proves attempted secure transport and refusal of the original HTTP endpoint, not successful TLS/body delivery.

## Grill Log

- **Q:** Can a missing cookie prove cookie blocking? **A:** Only after the same page's control request proves the seeded cookie reaches the server. Fresh values prevent old profile data from satisfying the check.
- **Q:** Does a transport attempt prove successful HTTPS delivery? **A:** No. The probe keeps successful TLS and upgraded method/body delivery as separate evidence requirements.
- **Q:** Does a page assertion alone prove interception? **A:** No. The server independently counts endpoint arrivals and verifies the POST payload.

## Dependencies and consumers

Uses [[Pudu Webview Header]], [[Pudu Webview Records]] and native platform adapters. Consumed by [[Desktop Webview CI]].

## Referenced by

[[src/_MOC]] · [[Desktop Webview CI]]

Resolved Grill Log: the test view is ephemeral; only synthetic first-party cookie state is needed.
