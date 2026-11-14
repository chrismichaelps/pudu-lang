---
type: handoff
status: ACTIVE
issue: 840
aliases: [Native Indexed Store Delivery]
---
# Native Indexed Store Delivery

Architect → Backend Engineer → Test Engineer → Forensic Guardian self-audit.
feature/840-native-indexed-stores starts at dev 81fcd2dc, after PR #829 was
merged under the standing C11 merge rule. Owned: Core's store type and keyed
operations; Lower Types, Keyed, Store (new), MultiMap (new), Intrinsic, Body,
Method, MethodValue, Generic, Scalar, Layout and Constant; the frame result
and ownership cases; Emit Cell, Keyed, Aggregate, Frame and Frame Value; the
hash runtime part (new) and its dependency edges; StorePrograms (new) and the
three spec registries; the mirror pages, ledger, navigation and history.
No sub-agents.

Resolved scope: [[Native Indexed Stores]]. `Buckets[V]` reuses the map
helpers at a narrowed Int key; `hashOf`, `mixHash`, `multiMapAdd` and
`multiMapContains` are direct calls and values. `Std.HashMap` and
`Std.MultiMap` compile natively.

Evidence: fourteen programs match the interpreter byte for byte, including
refusal text and spans; the six single-module success programs pass counted
allocation cleanup under `-pedantic -Werror`. Expected output was pinned
from reviewed interpreter runs; `hashOf("")` and `hashOf("a")` were checked
against the published constants of the walk. No conformance program prints a
mixed hash.

Not done: the ledger row stays Partial. SwissTable, buffer and column
kernels remain, as do the families listed in [[Native Emission Coverage]].
Windows evidence for the fixed-seed fallback is pending. No independent
semantic approval is claimed.

Exact next action: obtain independent review or an owner review exception
for the #840 PR, then lower the six SwissTable primitives over the store
carrier.

## Referenced by

[[handoffs/_MOC]] · [[Native Indexed Stores]]
