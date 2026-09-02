---
type: module
path: "@root/lib/Std/Http/Client.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, http, client, transport]
aliases: [Std Http Client]
---
# Std Http Client
## Purpose
Send a request somewhere and read what comes back, over a connection whose contents only the two
ends can read.
## Interface
What a request may cost: how many redirects it may follow, how large an answer it will read, and
which addresses it may reach. Sending a request to a URL and receiving the response. Fetching a URL
without building a request first. The refusals, and what each says.
## Governance and algorithm
**A secured scheme uses [[Std Tls]] and a plain one uses [[Std Net]]**, chosen from the URL rather
than from a setting, so a caller cannot ask for a secured address and silently get a plain
connection. Verification is not a parameter anywhere in the path.

**An address a request named is refused when it is one the network trusts.** A client that fetches
whatever it is handed is how a server is made to reach what only the server can reach — its own
loopback, the network it sits on, the address that answers with the credentials of the environment
it runs in. Refused by default, permitted by naming the host, because a service that genuinely must
reach an internal host exists and a refusal it cannot lift would be worked around outside this
module where nothing checks anything.

**Credentials do not survive a redirect to another origin.** This is the failure worth stating on its
own: a request carrying an authorization header, redirected to a host the caller never named, sends
that header to whoever operates it. The header is dropped when the origin changes, and every hop is
checked against the address rules as though it were the first — a redirect is a new request to a new
place, and treating it as a continuation is how the checks get skipped.

**How many redirects and how large an answer are bounded, and the bound is the caller's.** An
unbounded client is a way to exhaust the memory of the program that made the request rather than of
the one that answered it. A chain that would exceed the count, and a body that would exceed the
size, are refused rather than truncated: a truncated body is a body that parses to something the
sender did not send.

**A redirect that changes something becomes a request that changes nothing.** A permanent or
temporary redirect answered to a post is followed as a get, which is what the protocol's own
older codes mean and what every client does; the two codes that preserve the method are followed
with it preserved. Getting this wrong repeats a change.
## Grill Log
- **Q:** Keep the authorization header across a redirect, since the caller set it deliberately?
  **A:** No. _Rationale:_ the caller set it for the host they named, not for whichever host that one
  points at. _Rejected:_ carrying credentials through a redirect; carrying them within a site.
- **Q:** Truncate a body that exceeds the limit rather than refusing it? **A:** No. _Rationale:_ a
  truncated body parses to something the sender did not send, and the caller has no way to know.
  _Rejected:_ silent truncation.
- **Q:** Check the address only on the first request? **A:** No. _Rationale:_ a redirect to an
  internal address is exactly how the first check is bypassed. Every hop is a new request.
  _Rejected:_ checking the origin only.
- **Q:** Let a caller turn verification off for a self-signed certificate? **A:** No. _Rationale:_
  the same reasoning as [[Std Tls]]: a caller who could would eventually, to make something work,
  and the result looks secure. A machine that has been told about an internal authority is believed.
  _Rejected:_ an insecure mode.
- **Q:** Reuse connections between requests? **A:** Not yet. _Rationale:_ it is a real cost and a
  real design — which requests may share a connection is a question about identity and about what
  the far end may infer. Not worth guessing at. _Rejected:_ an implicit pool.
## Referenced by
[[src/Std/_MOC]] · [[Std Http]] · [[Std Tls]] · [[Std Net]] · [[Std Http Safe]] · [[ADR-0017 What the Web Layer Refuses]]
