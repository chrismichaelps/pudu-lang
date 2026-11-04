---
type: module
path: "@root/test-fixtures/ark/UsesArkNet.pudu"
fidelity: Active
aliases: [Ark Net Fixture]
tags: [module, ark, net, test]
---

# Ark Net Fixture

## Purpose and interface

Sends four packets, loses one and reorders two: duplicates are refused, the reply's ack bits
name exactly the received packets, acknowledgements retire oldest first, the lost packet stays
pending until it leaves the window and is counted, RTT is measured, sequences wrap, and stale or
out-of-range headers are refused. Checks exact header bytes and payload splitting. Replication
captures with rounding, round-trips a full and a partial delta, culls by radius into a despawn,
dequantizes and refuses malformed deltas and inputs. Prints `ark net: ok`.

## Resolved Grill Log

- **Q:** Simulate loss with randomness? **A:** No; a fixed loss and reorder pattern checks exact
  acknowledgement bits.

## Referenced by

[[Ark Net]] · [[Ark Replication]] · [[Ark Net Gate]] · [[src/Ark/_MOC]]
