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
- **Q:** Must every handler serialize values manually? **A:** No. Retain raw text reply APIs
  and add explicit typed helpers for the standard HTML and JSON models. Their names make the
  encoding boundary visible; custom encoders can continue to supply serialized text.
## Referenced by
[[src/Std/_MOC]] · [[Std Http Server]] · [[Std Http Server Route]] · [[Std Http Message]]

## Typed response integration

`view(code, Html.Html)` renders an HTML fragment, `page(code, Html.Html)` renders a document
with its doctype, and `jsonValue(code, Json.Json)` serializes through Std.Json. All delegate to
the existing reply/message path for media type and byte-length handling. Html.trusted and other
explicit trust escapes retain their existing meaning; these helpers do not sanitize trusted input.

Resolved Grill Log: Keep explicit status selection with the caller; do not infer success or
convert database errors into responses automatically. Serialization happens exactly once.

## Prepared server rendering

`rendered(code, Ssr.Rendered)` responds with an already rendered body and its recorded UTF-8
length, avoiding another HTML traversal or UTF-8 length calculation. Values produced by Ssr
constructors keep body and length consistent; manually constructed records must preserve that
invariant. Resolved Grill Log: do not rerender reusable output at the HTTP boundary.

## Conditional responses and ETags

`withEtag(response, etag)` attaches the ETag entity validator. `notModified(etag)` responds with
HTTP `304 Not Modified` and an empty body. `conditional(request, response, etag)` inspects the
incoming `If-None-Match` header: if the validator matches or contains `*`, it yields `notModified`
immediately, preserving 100% of body transport bandwidth on poor connections; otherwise it yields
the response with the ETag header attached. `computeEtag(body)` generates a fast hex hash.
`tooManyRequests(retryAfterSeconds)` emits RFC 6585 status 429 with `Retry-After`.
`serviceUnavailable(retryAfterSeconds)` emits RFC 7231 status 503 with `Retry-After`.
`gatewayTimeout(reason)` emits RFC 7231 status 504 for timeout conditions.

Grill Log:
- **Q:** Should `conditional` automatically compute ETags from the response body? **A:** No; callers
  supply the computed ETag or pre-computed revision hash to avoid hashing large bodies repeatedly.
- **Q:** Does 304 include headers from the original response? **A:** It preserves cache headers and
  the ETag validator without sending the body.
- **Q:** When should 503 be preferred over 429? **A:** 503 Service Unavailable is used when server
  capacity is exhausted or downstream dependencies are unavailable (backpressure/circuit breaker),
  whereas 429 Too Many Requests is used for client peer quota violations.


