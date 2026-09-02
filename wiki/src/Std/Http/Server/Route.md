---
type: module
path: "@root/lib/Std/Http/Server/Route.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, http, routing]
aliases: [Std Http Server Route]
---
# Std Http Server Route
## Purpose
Decide which handler answers a request, and give that handler what routing produced.
## Interface
The routed request, the handler and middleware shapes, route constructors for each method, a router
built from a list of them with a fallback, direct dispatch, and access to a captured parameter, a
query parameter, a header, and the body.
## Governance and algorithm
Routing needs no connection, so everything here is a value in and a value out and a program checks
its routes by calling them. Routes are tried in the order they are written, first match wins, and a
path that exists for another method is answered as a wrong method rather than as a missing path —
to a client those are different things. A trailing separator names the same place. The query is read
once and the path the router matches against has it removed, so no handler parses a target again.
## Grill Log
- **Q:** Let the most specific pattern win? **A:** No. _Rationale:_ source order is visible on the
  page and needs no comparison between patterns. _Rejected:_ scoring specificity.
- **Q:** Give handlers the connection? **A:** No. _Rationale:_ a handler that cannot reach a socket
  can be checked without binding a port. _Rejected:_ passing the connection through the request.
## Referenced by
[[src/Std/_MOC]] · [[Std Http Server]] · [[Std Http Server Reply]] · [[Std Http]]
