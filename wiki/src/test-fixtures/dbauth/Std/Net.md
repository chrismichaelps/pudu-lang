---
type: module
path: "@root/test-fixtures/dbauth/Std/Net.pudu"
fidelity: Active
tags: [database, authentication]
aliases: [Database Challenge Transport]
---
# Database Challenge Transport

## Purpose and interface

A fixture-owned transport supplies opening, receive, send, close and observed state. It opens no socket and selects an exchange by host name. State records pending bytes, sent proof count, read sizes and closure.

## Algorithm and resolved Grill Log

After startup offer the challenge mechanism. Parse the client nonce from the initial message, prepare a server first phase and independently compute the expected client proof and server signature for the fixed fixture password. Inject selected first/final defects or an oversized header. Validate the actual proof before sending final proof and ready messages. A delayed complete challenge crosses the opening deadline before proof admission. Receive honors the requested byte count; closed operations refuse. Keep the last connection observable for post-failure cleanup assertions.

- **Q:** Predict the secure nonce? **A:** No; bind responses to the nonce actually sent.
- **Q:** Count a valid connection as proof of refusal cleanup? **A:** No; every refusal observes its closed transport and proof count.

## Referenced by

[[Database Challenge Fixture]] · [[src/_MOC]]
