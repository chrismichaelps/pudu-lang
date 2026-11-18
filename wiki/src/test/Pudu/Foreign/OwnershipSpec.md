---
type: module
path: "@root/test/Pudu/Foreign/OwnershipSpec.hs"
fidelity: Active
grammar: Haskell
aliases: [Foreign Ownership Tests]
---

# Foreign Ownership Tests

Exercise ownership generations, batch admission, counted references,
invocation leases, transfer and teardown directly against the store.

## Interface

The property list is consumed by the repository test runner. Cleanup
counters expose double release and lost cleanup without native destructors.

## Resolved Grill Log

A transfer rejects a busy generation and prevents new leases. A failure
before native entry restores the original generation and ownership table.
Entered transfers leave the former generation stale. Counted references
remain independent when several claims share an address.

## Referenced by

[[Foreign Ownership]] · [[src/test/_MOC]]

## Resolved Grill Log for loader ownership

Open references independently and call a real libc symbol. Closing one
reference must reject its future users while another reference remains
callable. Exceptions from a scoped symbol action must return its lease.
