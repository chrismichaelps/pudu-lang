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
Read requests off connections, answer them, and stop when asked.
## Interface
A server over a router, the chain of steps wrapped around its handlers, the limits a request may
not exceed, starting and stopping a listener, serving one connection or accepting until a bound is
reached, and a step that reports every request once its answer is known. Routing is
[[Std Http Server Route]] and the answers themselves are [[Std Http Server Reply]].
## Governance and algorithm
The head and body limits are not tuning: without them a client that opens a connection and never
sends the blank line ending the head makes the server hold everything it did send, and enough such
clients are the whole of the attack. Each connection is served on its own thread, so one slow
request does not hold up every other client. Every response states its own length, so a client
knows where the body ends without waiting for the connection to close to tell it. A malformed
message is answered rather than raised — a server told nonsense is working correctly when it says
so — while a listener that failed stays a `ServerError`. Closing the listener is what ends the
accept loop, because accepting does not answer until a connection arrives; the flag says the
failure was asked for.
## Grill Log
- **Q:** Rebuild the chain of steps per request? **A:** No. _Rationale:_ it is the same for every
  request, and rebuilding would put the server's whole configuration in its hot path. _Rejected:_
  unlimited request buffering; socket access in handlers.
- **Q:** Close the connection after each request? **A:** No. _Rationale:_ opening one costs a round
  trip and a client fetching a page makes many requests. _Rejected:_ ignoring the header that asks
  for it to close.
## Referenced by
[[src/Std/_MOC]] · [[Std Http Server Route]] · [[Std Http Server Reply]] · [[Std Http]] · [[Std Net]] · [[architecture/STDLIB]]
