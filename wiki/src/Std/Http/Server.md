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
[[src/Std/_MOC]] · [[Std Http Server Lambda]] · [[Std Http Server Route]] · [[Std Http Server Reply]] · [[Std Http]] · [[Std Net]] · [[architecture/STDLIB]]

## Request read deadlines

Server.readMillis defaults to 30000 and is set through Server.withReadDeadline. Application
configuration server.readMillis must be in 1..86400000 and is validated before startup. One
absolute clock deadline covers both header and body through Std.Net.Read, including idle
keep-alive reads. Header limits count delimiter bytes. This does not interrupt handler work,
bound response writes or impose a complete shutdown deadline.
Resolved Grill Log: retain an absolute deadline across partial reads; timeout per packet lets
a slow sender hold a worker indefinitely.

## Bounded response writes

Server.writeMillis defaults to 30000, configured by withWriteDeadline and server.writeMillis
(1..86400000 at application startup). Both ordinary and fallback responses use Net.sendTextWithin.
A failed/expired write ends connection reuse. The budget covers socket sending, not handler
execution or response serialization. Tune for expected payload sizes and slow legitimate clients;
timeouts protect capacity and do not increase available network bandwidth.
Resolved Grill Log: bound fallback writes too, and preserve configured deadlines through server
copy helpers. No tests, builds, reviews or measurements run.

## Bounded connection workers

Server uses workers=16 persistent consumers and queueCapacity=64 waiting connections by default.
withWorkers configures both. App validates server.workers in 1..1024 and server.queueCapacity
in 1..65536 before startup. A bounded channel applies backpressure to accept; at most one extra
accepted connection can wait in the producer. The operating-system listen backlog is separate.
Worker handles are bounded by worker count, rather than total lifetime connections.

After acceptance ends the channel closes, queued work drains, and all workers are joined. A
failed worker start closes the queue and joins started workers before returning an error. A
failed queue send closes its accepted connection. Join failures are surfaced. Workers check the
stop flag between keep-alive requests. Handler abort/cancellation cleanup and bounded overall
shutdown remain unresolved; a handler that never returns can still hold one worker indefinitely.
Resolved Grill Log: fixed workers bound tasks and retained handles; do not describe the connection
accept count as concurrency. Do not discard worker-start or join errors. No tests or reviews run.

## Worker handler reuse

Each worker composes its middleware handler once before receiving connections, then passes that
handler into the internal request-serving function. Public serveConnection still composes a
handler for standalone use. Middleware invocation order and request-local results are unchanged.
Resolved Grill Log: reuse the immutable handler closure, never a response or request value.

## Graceful draining deadline

`Server.drainMillis` defaults to 10000ms and is configured via `withDrainDeadline(base: &Server, millis: Int) -> Server`.
When `Server.run` or `Server.listenAndServe` is asked to stop, the listener is closed and the incoming queue finishes.
In-flight worker draining is bound by `drainMillis`: worker tasks are joined concurrently against an asynchronous
deadline timer. If in-flight requests do not drain within `drainMillis`, `Server.run` aborts waiting and reports
`Err(Other("worker draining deadline exceeded"))` rather than blocking indefinitely.

Resolved Grill Log:
- **Q:** Why bound worker joining with a deadline? **A:** If a slow client or long-running request hangs, unbounded joining causes deployment orchestrators (Kubernetes / systemd) to SIGKILL the process abruptly, corrupting unclosed streams. A draining deadline allows in-flight requests a graceful completion window before forcing termination.


## TLS and binary compression implementation contract

Socket output uses renderResponseBytes and Net.sendWithin. Framing is regenerated from actual payload bytes, removing user Transfer-Encoding and Content-Length. HEAD emits no body but retains selected representation length; 1xx, 204, 205, and 304 emit no payload under status-specific framing rules.

Resolved Grill Log: protocol bytes must remain bytes; verified transport cannot downgrade. Errors remain explicit and resource ownership transfers once. Implementation is code-only; no validation or readiness claim.

## High-performance request pipeline and keep-alive caching

`readRequest` uses `Message.parseHead` directly on the delimited head string, avoiding re-concatenating and re-scanning `\r\n\r\n`. In persistent keep-alive connections (`serveWith`), `Net.peerOf(connection)` is cached per connection rather than invoking the `getpeername()` system call on every request.

Resolved Grill Log: the server read loop must not reconstruct delimiters that the byte transport already split; peer identity is static for the lifetime of a connection and must not incur repeated OS context switches.
