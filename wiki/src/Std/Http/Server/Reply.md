---
type: module
path: "@root/lib/Std/Http/Server/Reply.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, http, response]
aliases: [Std Http Server Reply]
---
# Std Http Server Reply
## Purpose
Build the answers a handler gives, without a request or a connection in hand.
## Interface
Responses carrying text, HTML, or already-encoded JSON; a response with a status and no body; the
header advertising which media types a resource reads; and the two refusals a body receives.
## Governance and algorithm
A reply is the one part of serving a program builds with nothing else present, which is why it is
its own module: a test naming an expected response, a middleware refusing one, and a handler
answering one all want these and none of them wants a server. A refusal states what would have been
acceptable, because one that only said no would leave the client guessing. A body in a type the
resource cannot read and a body it read but could not act on are separate answers — one says the
type was wrong, the other says the content was, and a client acts differently on each.
## Grill Log
- **Q:** Encode JSON here? **A:** No. _Rationale:_ the content is already text by the time a status
  is being chosen, and encoding here would tie every reply to one encoder. _Rejected:_ taking a
  value and serialising it.
## Referenced by
[[src/Std/_MOC]] · [[Std Http Server]] · [[Std Http Server Route]] · [[Std Http Message]]
