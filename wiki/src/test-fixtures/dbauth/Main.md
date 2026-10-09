---
type: module
path: "@root/test-fixtures/dbauth/Main.pudu"
fidelity: Active
tags: [database, authentication]
aliases: [Database Challenge Fixture]
---
# Database Challenge Fixture

## Purpose and interface

Exit zero only after pure challenge boundary assertions and actual Session.connect exchanges pass. The production validator and session remain the subject; only the transport is fixture-owned.

## Algorithm and resolved Grill Log

Exercise exact payload admission and one-byte-over refusal, declared budget constants and admitted round boundaries, field order, optional extensions, canonical encodings and nonce binding. Refuse malformed, signed, leading-zero, zero, excessive and overflowing rounds, duplicate/missing fields, mandatory extensions, invalid text/phase/nonce/salt/proof and oversized payloads. Valid transport exchanges prove exact client proof and successful opening. First-phase refusals send no proof, oversized frames consume only their header, final proof failures close, an expired opening writes no proof, and all failed opens close the transport. Preserve diagnostic identity and wording without echoing challenge data.

- **Q:** Substitute cryptographic admission? **A:** No; execute the production code and use a published proof vector as an independent control.
- **Q:** Assert only Err? **A:** No; pin selected error cases/text and observed proof/read/close behavior.

## Referenced by

[[Database Challenge Spec]] · [[Database Challenge Transport]] · [[Std Db Challenge]] · [[src/_MOC]]
