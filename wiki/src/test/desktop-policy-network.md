---
type: module
path: "@root/test/desktop-policy-network.mjs"
fidelity: Active
aliases: [Desktop Policy Network Gate]
tags: [module, test, desktop, network, policy]
---
# Desktop Policy Network Gate

## Purpose and interface

Own an ephemeral loopback HTTP server and a fresh seeded first-party cookie. Run the native harness asynchronously so requests can be served. Require control cookie presence, protected cookie absence with POST body preserved, zero blocked-endpoint arrivals and a successful page report. Optional upgrade mode observes a TLS ClientHello against the HTTP listener and zero original upgrade-endpoint arrivals. Always close child/server connections on timeout or failure; no external network or persistent trust changes.

## Grill Log

- **Q:** Can a missing cookie prove cookie blocking? **A:** Only after the same page's control request proves the seeded cookie reaches the server. Fresh values prevent old profile data from satisfying the check.
- **Q:** Does a transport attempt prove successful HTTPS delivery? **A:** No. The probe keeps successful TLS and upgraded method/body delivery as separate evidence requirements.
- **Q:** Does a page assertion alone prove interception? **A:** No. The server independently counts endpoint arrivals and verifies the POST payload.

## Dependencies and consumers

Uses [[Pudu Webview Header]], [[Pudu Webview Records]] and native platform adapters. Consumed by [[Desktop Webview CI]].

## Referenced by

[[src/_MOC]] · [[Desktop Webview CI]]

Resolved Grill Log: record violations across every protected arrival, so a later retry cannot overwrite evidence of a leaked cookie or changed body.

Resolved Grill Log: a protected response attempts to plant a fresh cookie. A subsequent unprotected control request must not carry it, independently checking response-cookie storage rather than outgoing header mutation alone.

Resolved Grill Log: --https uses caller-provided certificate/key files and local ports 80/443. The original HTTP trap must receive zero upgrade requests; the trusted HTTPS server must receive the fresh POST token unchanged and return it to the real page through CORS. This mode proves successful secure delivery separately from the transport-only probe. All listeners and children close through finally cleanup.

Resolved Grill Log: derive the attempted response-cookie name from the fresh seed, preventing stale profile state from falsely implicating this run even when a backend cannot supply ephemeral storage.
