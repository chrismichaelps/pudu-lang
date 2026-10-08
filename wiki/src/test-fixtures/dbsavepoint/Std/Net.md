---
type: module
path: "@root/test-fixtures/dbsavepoint/Std/Net.pudu"
fidelity: Active
tags: [test, transport, database]
aliases: [Savepoint Fixture Transport]
---
# Savepoint Fixture Transport

## Purpose and interface

A fixture-owned `Std.Net` substitute provides connection, receive, send, close and opening
operations. `fake` creates a connection and `state` exposes observed commands, unread replies,
active mark names, peak depth, selected refusal command and closed admission.

## Algorithm

Read framed simple commands, record their exact text and independently maintain a mark stack.
Rollback to a mark keeps that mark; release removes it and any deeper marks. Search from the
most recent matching name so repeated names restore the enclosing mark correctly. A configured
command refusal leaves ownership unchanged and emits a structured failure plus a ready boundary.
Every successful command emits completion and ready messages. Receive respects the requested
byte count. Closed transports refuse operations, opening is unsupported, and unread responses
must be consumed before another command. The substitute opens no sockets.

## Resolved Grill Log

- **Q:** Derive mark depth from the production helper? **A:** No; model protocol ownership independently.
- **Q:** Treat duplicate names as one mark? **A:** No; the most recent occurrence owns each operation.
- **Q:** Fail all cleanup at once? **A:** No; inject one exact command to prove ordering and cause retention.

## Referenced by

[[Database Savepoint Fixture]] · [[src/_MOC]]
