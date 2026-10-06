---
type: module
path: "@root/website/src/Web/Access.pudu"
fidelity: Active
tags: [website, http, logging]
aliases: [website Web Access]
---
# Website Web Access

One structured access event per request: method, path, status, and elapsed milliseconds, at
information, warning for a 4xx refusal that is not a 404, and error for a 5xx. `middleware` wraps the
local server's router; `around` wraps a direct dispatch, which is how the function and the renderer
answer. The query string is never logged: a shared playground link carries a whole program in it.

Resolved Grill Log: the access log sits at the HTTP edge because it is about requests, including
assets and package pages that never reach the mediator. _Rejected:_ logging the full target
(programs and search terms in logs).
