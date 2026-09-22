---
type: module
path: "@root/registry/src/Test/Registry.pudu"
fidelity: Active
tags: [registry, tests]
aliases: [registry Test Registry]
---
# Registry Test Registry

The registry suite: manifest rules, archive refusals, accounts and tokens, release rules (immutability, major-line order, version match, ownership, look-alike names, yanking), private visibility through the routes, search, and the device flow.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Test over a socket? **A:** Through `Route.dispatch`. _Rationale:_ the routes are the contract; the socket is `Std.Http.Server`'s.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
