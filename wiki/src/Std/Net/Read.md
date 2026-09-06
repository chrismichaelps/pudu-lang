---
type: module
path: "@root/lib/Std/Net/Read.pudu"
fidelity: Active
tags: [module, network]
aliases: [Std Net Bounded Read]
---
# Std Net Bounded Read

until reads a delimiter with a byte limit including the delimiter, using an absolute monotonic
clock deadline; exactly reads a count with the same deadline convention. Negative lengths and
empty delimiters fail. Each receive is capped to remaining admission bytes and remaining time.
EOF and empty reads refuse progress. A delimiter ending beyond the limit is never accepted.
Fragments are still accumulated as Bytes; this is not a zero-copy parser.

## Grill Log

- **Q:** Renew timeout for every packet? **A:** No; use one absolute deadline to bound slow drip.
- **Q:** Accept an oversized final delimiter chunk? **A:** No; cap reads before allocation.

## Referenced by
[[src/Std/_MOC]] · [[Std Http Server]]
