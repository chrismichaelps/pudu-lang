---
type: module
path: "@root/lib/Std/Http/Server.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, http, server]
aliases: [Std Http Server]
---
# Std Http Server
## Purpose
Serve HTTP/1 request/response handlers through deterministic routing and explicit resource limits.
## Interface
Exports route/router/server values, path and query extraction, middleware, direct dispatch,
listener lifecycle, bounded serving, and common response constructors.
## Governance and algorithm
Handlers never receive sockets and can be tested as pure functions. Routes are first-match in source
order; request head/body limits are enforced before buffering; malformed input receives a protocol
response while listener failures remain `ServerError` values.
## Grill Log
- **Q:** Let the most specific route win? **A:** No. _Rationale:_ first-match order is visible and
  deterministic without comparing every pattern. _Rejected:_ unlimited request buffering; hidden
  middleware order; socket access in handlers.
## Referenced by
[[src/Std/_MOC]] · [[Std Http]] · [[Std Net]] · [[architecture/STDLIB]]
