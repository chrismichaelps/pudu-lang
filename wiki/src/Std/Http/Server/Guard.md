---
type: module
path: "@root/lib/Std/Http/Server/Guard.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, http, security, middleware]
aliases: [Std Http Server Guard]
---
# Std Http Server Guard
## Purpose
The steps a service wraps around its handlers so that it is safe before anyone has thought about it.
## Interface
`standard` — every protection below, in the order they belong. Beneath it, each on its own:
protective response headers; a cross-origin permission built from an allowlist; a refusal of
state-changing requests that came from another site; a request identity carried into the answer; a
step that turns an unexpected failure into a status and a sentence; and the settings each takes when
the defaults are wrong for a particular service.
## Governance and algorithm
**The protections are on and are turned off deliberately.** A switch has an off position and turns
whether a service is protected into a property of a deployment rather than of its code. There is no
switch: a program that needs a laxer setting writes the laxer step, and that line is in its source
where a reviewer sees it.

The response headers are the maintained industry set and mean, in order: do not frame this, do not
guess its type, do not send a referrer, permit only this page's own origin and no objects or frames,
isolate it from other origins, and do not store it. Together they cover the failures a page cannot
defend against from inside itself.

**Nothing says what this is.** No name and no version, in any header. The published list of headers
to strip is largely a list of frameworks that disclosed themselves, and the disclosure is what turns
a published advisory into a targeted request. There is no setting for this because there is no
reason to want it.

**A cross-origin permission is an allowlist and nothing else.** No wildcard with credentials, and no
reflecting back whichever origin asked — the reflecting form is indistinguishable from having no
policy, and is what a misconfiguration looks like from the outside. An origin that is not on the
list receives no permission header, rather than a header permitting nothing, because the absence is
what the browser is specified to act on.

**Provenance is checked before a token.** A defence the browser enforces cannot be forgotten by a
page author, so it is the first line; a token remains available for what the header does not cover.

**A failure says that it failed.** What crosses the network is a status and a sentence. The detail
goes where it is useful, and the identity in both is what lets an operator handed one find the
other. This is deliberate: an error page that explains itself is a reconnaissance tool.
## Grill Log
- **Q:** Offer one setting that enables the protections? **A:** No. _Rationale:_ a switch has an off
  position, and then whether a service is protected depends on a deployment rather than on its code.
  _Rejected:_ a `secure` flag.
- **Q:** Reflect the requesting origin when it is not on the list? **A:** No. _Rationale:_ reflecting
  is the same as permitting everything, and it is what a misconfiguration produces.
  _Rejected:_ echoing the origin; a wildcard alongside credentials.
- **Q:** Include the failure's detail for a request from the same machine? **A:** No. _Rationale:_ a
  rule keyed on the peer is a rule that is wrong behind a proxy, which is where services run.
  _Rejected:_ detail for loopback callers.
- **Q:** Refuse a state-changing request that states no provenance? **A:** Yes. _Rationale:_ an old
  client and a hostile one are indistinguishable, and only one reading is safe for both. The cost is
  that a very old client cannot post, which is the correct trade. _Rejected:_ trusting silence.
## Rate limiting middleware

`rateLimited(maxRequests: Int, windowSeconds: Int) -> Route.Middleware` protects routes from brute-force
and denial-of-service surges. Tracks peer request frequencies per moving window in thread-safe cell storage.
When a peer exceeds `maxRequests` within `windowSeconds`, the middleware refuses the request with
`Reply.tooManyRequests(windowSeconds)` and sets `Retry-After: {windowSeconds}`, halting further handler
invocation and preventing downstream database and compute exhaustion.

Grill Log:
- **Q:** How are peers identified for rate limiting? **A:** Using `request.peer`, or fallback to `"client"`
  when peer address is unstated.
- **Q:** Is rate limiting global or per worker? **A:** Global state shared across server workers via a
  synchronized reference cell, ensuring distributed throttling across the connection pool.

## Bounded concurrency and backpressure middleware

`boundedConcurrency(maxInflight: Int) -> Route.Middleware` limits active concurrent requests in flight.
When active requests reach `maxInflight`, excess requests are shed immediately with `Reply.serviceUnavailable(1)`
and `Retry-After: 1`, preventing memory exhaustion and thread thrashing under load surges.

## Circuit breaker middleware

`circuitBreaker(failureThreshold: Int, resetTimeoutSeconds: Int) -> Route.Middleware` protects downstream
services and database layers from cascading failures. Tracks consecutive 5xx errors:
when failures reach `failureThreshold`, the circuit breaker trips open, failing fast with `Reply.serviceUnavailable`
for `resetTimeoutSeconds`. Once the timeout expires, it permits a probe request (half-open) and resets upon success.

Grill Log:
- **Q:** Why shed load with 503 instead of queueing indefinitely? **A:** Unbounded request queues hide
  overload and cause memory exhaustion or cascading timeouts. Fast-shedding with 503 allows load balancers
  and retry policies to redistribute traffic.
- **Q:** What errors trip the circuit breaker? **A:** Only server error statuses ($\ge 500$). Client
  errors ($4xx$) do not trip the breaker.
## Request execution deadline middleware

`timeout(timeoutMs: Int) -> Route.Middleware` bounds request handler execution time.
Races handler execution against an asynchronous deadline timer using a bounded synchronization
channel. If the wrapped handler fails to produce a response within `timeoutMs`, the middleware
aborts waiting and returns RFC 7231 status 504 Gateway Timeout (`Reply.gatewayTimeout("request execution deadline exceeded")`).

Grill Log:
- **Q:** Why race via a channel rather than polling? **A:** Polling burns CPU cycles and introduces latency jitter. Racing on a bounded channel with `Concurrent.sleep` wakes the receiver immediately when either the response arrives or the timer expires.
- **Q:** What happens to the slow handler task after timeout? **A:** The channel has capacity 2, so the slow worker can deliver its finished result without deadlocking, and exits cleanly.

## Audit logging middleware

`audited(log: &Audit.AuditLog, action: Str) -> Route.Middleware` connects HTTP routes to the
tamper-evident security audit trail in [[Std App Audit]].
Constructs an audit event capturing request method, path, peer IP, and `X-Request-Id`. Maps HTTP
response status codes to audit outcomes: statuses `< 400` map to `Outcome.Success`, `401` and `403`
map to `Outcome.Denied`, and statuses $\ge 500$ map to `Outcome.Failure`.

Grill Log:
- **Q:** Should the request body be logged in the audit trail? **A:** No. Request bodies frequently contain passwords, session tokens, or personal identifiers. The audit trail captures principal identity, resource target, and outcome, leaving body inspection to dedicated data-loss prevention layers.

## Referenced by
[[src/Std/_MOC]] · [[ADR-0017 What the Web Layer Refuses]] · [[Std App Audit]] · [[Std Http Safe]] · [[Std Http Server]] · [[Std Http Server Route]] · [[Std Http Server Reply]]




## Binary payload migration

Text response literals initialize binaryBody: None. Header-only response copies preserve binaryBody. Reply.bytes constructs an exact binary payload.
Resolved Grill Log: changing headers must not discard encoded bytes; text replacement must clear the binary override.
