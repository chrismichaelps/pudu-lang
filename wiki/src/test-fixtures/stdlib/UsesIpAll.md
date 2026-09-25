---
type: module
path: "@root/test-fixtures/stdlib/UsesIpAll.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, network]
aliases: [Uses Ip All]
---

# Uses Ip All

## Purpose and interface

Executable fixture for [[Std Ip]]. Its `main` returns 55 held assertions, each reaching an export.

Parsing and RFC 5952 rendering in both families (compression of the longest run, a tie, no
compression of a single zero group, `::`, mapped and embedded dotted tails); every refusal and its
sentence, including a zone suffix, two `::`, a `::` standing for no group, and a leading zero;
bytes both ways; the mapped-peer regression that an IPv4 allowlist must still hold
`::ffff:10.1.2.3` through `within` while `contains` stays family-exact; neighbours at the family's
ends; each classification once holding and once not; and networks — strict reading, masking,
edges, netmask, overlaps across and within families, and prefix refusals.

## Grill Log

- **Q:** Compare rendered text or values? **A:** Both. _Rationale:_ canonical text is the contract a
  log reader sees, and value equality is what a rule uses.

## Referenced by

[[Std Ip]] · [[Runtime Evaluation Spec]]
