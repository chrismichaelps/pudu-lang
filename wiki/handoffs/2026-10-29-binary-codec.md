---
type: handoff
status: ACTIVE
aliases: [Binary Codec Delivery]
tags: [handoff, runtime, serialization]
---
# Binary Codec Delivery

Issue #739 runtime partition owns Eval.Binary, native codec properties, package/test registration
and matching mirrors/navigation. Architect resolved the wire contract and exact-bit oracle before
implementation; Runtime Engineer implements; Tooling/Release validates. Preserve ongoing library,
builtin-wiring and benchmark work in this checkout. No delegated agents or merges.

The native property families pass 200 generated canonical round trips, 200 strict-truncation
cases, and fixed malformed/nesting/golden boundaries. The optimized warning-free build passes.
The clean full repository gate passed on the working continuation; the native properties also
passed after adding deliberately reversed field order. Hosted checks must validate this isolated
partition without the pending facade/wiring edits. Independent implementation, Language
Architect and Forensic Guardian reviews remain pending; no self-approval.

This partition does not complete #739: the public Encode/Decode derives, runtime builtin wiring,
evolution fixture, serialization benchmark and facade delivery remain required.

Exact next action: publish the native partition as a draft PR to dev, then finish the separate facade/wiring delivery after its prerequisite is integrated.

## Referenced by

[[handoffs/_MOC]] · [[Eval Binary]] · [[Binary Codec Properties]]
