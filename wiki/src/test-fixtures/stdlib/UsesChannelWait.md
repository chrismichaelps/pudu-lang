---
type: module
path: "@root/test-fixtures/stdlib/UsesChannelWait.pudu"
fidelity: Active
tags: [test, channel, lifecycle]
aliases: [Uses Channel Wait]
---
# Uses Channel Wait

## Purpose and interface

The zero-returning entry verifies `Std.Channel.receiveWithin` through immediate timeout, value,
closed-empty, closed-with-queued-value, nested optional payload and explicit invalid-input paths.
Repeated timeout followed by send and receipt proves that expiry never removes future messages.
Existing blocking receipt remains compatible. No external transport is used.

## Resolved Grill Log

- **Q:** Represent timeout as closure? **A:** No; compare exact public variants and complete payloads.
- **Q:** Accept any completed entry? **A:** No; register an exact zero result in the fixture runner.

## Referenced by

[[Protocol Evaluation Spec]] · [[Std Channel]] · [[src/_MOC]]
