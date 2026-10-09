---
type: module
path: "@root/test-fixtures/dbwait/Std/Net.pudu"
fidelity: Active
tags: [test, database, transport]
aliases: [Database Admission Transport]
---
# Database Admission Transport

## Purpose and interface

Source-local network substitution for [[Database Admission Fixture]]. Connections hold shared state with pending complete frames, command history, startup and closed flags. Fake idle connections support pool ownership checks; opening supplies complete authentication and ready replies.

## Invariants and failures

A startup is admitted once. Ordinary commands require the previous response to be consumed; begin and commit report their matching status and complete command boundaries. Termination and explicit close preserve observable closed state. Reads return at most the requested bytes and preserve surplus. Unexpected commands or unread response state are typed refusals rather than fabricated success.

## Resolved Grill Log

- **Q:** Mock the bounded channel primitive? **A:** No; only network bytes are controlled.
- **Q:** Ignore command ordering? **A:** No; command history and complete ready replies expose adapter misuse.

## Referenced by

[[Database Admission Fixture]] · [[src/_MOC]] · [[Database Admission Delivery]]
