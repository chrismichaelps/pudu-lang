---
type: module
path: "@root/lib/Ark/Net.pudu"
fidelity: Active
aliases: [Ark Net]
tags: [module, ark, net]
---

# Ark Net

## Purpose and interface

Transport-agnostic reliability over unreliable datagrams. `Header` carries a 16-bit `sequence`,
the newest sequence received from the peer (`ack`) and 32 `ackBits` where bit i names
`ack - 1 - i`. `endpoint()` starts a side; `send(endpoint, now)` stamps the next packet and
counts a pending packet that leaves the window unanswered as lost; `receive(endpoint, header,
now)` records the peer's sequence for our next acks, retires every pending packet the header
acknowledges (oldest first) and updates a smoothed RTT (new samples weigh one eighth). Duplicates,
packets older than the window and out-of-range fields answer None. `newer` compares sequences
under wrap-around. `encode`/`decode` use eight little-endian bytes ahead of the payload.

## Resolved Grill Log

- **Q:** Resend lost packets here? **A:** No; games resend state, not packets. The endpoint
  reports what arrived and what was lost, and replication decides what to send next.
- **Q:** Use wall-clock time inside? **A:** No; callers pass `now`, so sessions replay exactly.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Replication]] · [[Ark Net Fixture]] · [[Ark Net Gate]]
