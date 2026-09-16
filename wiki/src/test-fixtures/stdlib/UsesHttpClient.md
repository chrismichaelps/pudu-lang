---
type: module
path: "@root/test-fixtures/stdlib/UsesHttpClient.pudu"
fidelity: Active
---
# UsesHttpClient

## Purpose and interface
Exercises HTTP client bounds, internal-host permission, redirects, UTF-8 request lengths, chunked
responses, size limits, shared deadlines, and real loopback transport.

The fixture also owns a raw loopback peer that sends a complete `Content-Length` response, keeps the
socket open beyond the client's deadline, and closes later. The client must return the framed body
before that close; waiting for EOF produces `TimedOut` and loses the assertion.

## Grill Log
- **Q:** Let the ordinary Pudu server provide the persistent response? **A:** No. _Rationale:_ it
  honors the client's `Connection: close`, so it cannot reproduce a peer that keeps the transport
  open. _Rejected:_ a test that closes at the same point as the response.
- **Q:** Measure elapsed milliseconds? **A:** No. _Rationale:_ the client's shorter deadline makes
  completion versus EOF waiting deterministic without a timing threshold assertion. _Rejected:_
  wall-clock performance as protocol correctness.

Resolved Grill Log: a controlled raw peer proves framing ends the message independently of socket
closure.

## Referenced by
[[Std Http]] · [[Std Http Client]] · [[Protocol Evaluation Spec]]
