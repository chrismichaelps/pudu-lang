---
type: design
fidelity: Historical
tags: [runtime, performance, history]
aliases: [Eval MultiMap Kernel]
---

# Eval MultiMap Kernel

The implementation now lives in [[Eval Loop Kernel]]. Its original pure-region
proof and captured MultiMap primitive checks are retained. Scalar-only regions
can use the same proof without containing a primitive call.

Resolved Grill Log: module ownership follows the complete pure-loop responsibility;
retain this historical link for earlier performance records and handoffs.

## Referenced by

[[Eval Loop Kernel]] · [[2026-10-01-multimap-performance]]
