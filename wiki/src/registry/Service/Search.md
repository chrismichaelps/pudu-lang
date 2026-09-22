---
type: module
path: "@root/registry/src/Service/Search.pudu"
fidelity: Active
tags: [registry, search]
aliases: [registry Service Search]
---
# Registry Service Search

`search` ranks public, listed projects: exact name, then handle, then name containing the query, then every word found in description or keywords; ties by name; `PAGE_SIZE` per page.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Include private projects for their owner? **A:** Not in search. _Rationale:_ search results feed public pages. _Rejected:_ viewer-dependent results.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
