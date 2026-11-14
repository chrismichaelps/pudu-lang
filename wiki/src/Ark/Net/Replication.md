---
type: module
path: "@root/lib/Ark/Net/Replication.pudu"
fidelity: Active
aliases: [Ark Replication]
tags: [module, ark, net]
---

# Ark Replication

## Purpose and interface

`Schema` gives each field's quantization step. `capture(schema, ids, columns)` rounds float
lane columns to integer quanta with native lane kernels; `restore` dequantizes. `relevant(xs, ys,
zs, x, y, z, radius)` answers the rows strictly inside an interest radius through lane masks.

`delta(baseline, current, rows)` encodes the chosen rows against the snapshot the peer last
acknowledged: a varint entity count, then per entity a zigzag id, a field bitmask and zigzag
varint differences for changed fields (every field for an entity the baseline lacks), then the
ids present in the baseline but not sent, which despawn. `apply(baseline, encoded)` reverses it,
keeping unsent baseline entities that were not despawned, and refuses truncation, trailing bytes,
repeated ids, masks naming unknown fields and partial updates without their baseline entity.

## Resolved Grill Log

- **Q:** Send floats verbatim? **A:** No; per-field quantization fixes precision on the wire and
  makes unchanged values compare exactly, so deltas omit them.
- **Q:** Track per-client baselines here? **A:** No; the caller keeps the snapshot each client
  acknowledged through [[Ark Net]] and passes it in.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Net]] · [[Ark Net Fixture]]
