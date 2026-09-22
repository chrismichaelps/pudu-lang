---
type: module
path: "@root/registry/src/Service/Clock.pudu"
fidelity: Active
tags: [registry, time]
aliases: [registry Service Clock]
---
# Registry Service Clock

`stamp` (RFC 3339 UTC) and `millis` (epoch milliseconds).

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Local time? **A:** UTC. _Rationale:_ documents are compared across machines.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
