---
type: module
path: "@root/test-fixtures/dbbuffer/Std/Net.pudu"
fidelity: Active
tags: [test, transport, database]
aliases: [Database Fixture Transport]
---
# Database Fixture Transport

## Purpose and interface

A fixture-owned transport implements the session's connection, receive, send, close and opening
surface with exact byte delivery, configurable fragmentation and recorded read requests.

## Algorithm

Connections name synchronized state containing unread bytes, request sizes and closed admission.
Each receive returns at most the requested bytes and configured fragment size. EOF returns absence.
Close is observable. The connection token is also the state-cell token so the production session
record shape remains unchanged. It opens no sockets and supports no real connection startup.

## Resolved Grill Log

- **Q:** Depend on transport packet boundaries? **A:** No; control exact fragmentation.
- **Q:** Let a closed substitute keep delivering bytes? **A:** No; refuse closed admission.

## Referenced by

[[Database Buffered Read Fixture]]
