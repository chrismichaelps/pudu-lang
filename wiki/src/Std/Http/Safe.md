---
type: module
path: "@root/lib/Std/Http/Safe.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, http, security]
aliases: [Std Http Safe]
---
# Std Http Safe
## Purpose
The judgements a server must make before it believes a request, as functions on values.
## Interface
How long a body a message says is coming, refusing a message that says it two ways. Whether a header
name and value may be written. Where a request came from, as the browser stated it. Whether a
redirect target is one the program named. A path resolved under a root it cannot leave. Whether an
address is one a server should not be asked to reach. The refusal each of these gives, and what it
says.
## Governance and algorithm
Every judgement here is a pure function, which is what lets each be checked by supplying the attack
and asserting the refusal, without a socket and without a server.

**A message states its length once or it is refused.** Both a length and a chunked encoding, or two
lengths that disagree, is not an ambiguity to resolve: it is a message built to be read differently
by two things in a chain, and adopting a precedence rule is how the two readers come to disagree.
There is no rule, so there is nothing for an attacker to exploit the difference between.

**A line break in a header is refused rather than escaped.** Escaping guesses what the sender meant;
no legitimate value contains one, so refusing loses nothing and admits nothing.

**Provenance is read from what the browser stated and cannot be forged by a page.** The request's own
account of whether it came from this site is checked before any token is. A token is a second line,
not the first, because a defence the browser enforces cannot be forgotten by a page author. A request
that states nothing is treated as cross-site when the method changes something, since an old client
and a hostile one are indistinguishable and the safe reading is the same for both.

**A path is resolved by walking it, never by looking for a shape.** Segments are consumed one at a
time and an ascent past the root refuses; the escaping that defeats substring filters has already
happened by the time a segment exists, so there is nothing left for it to hide in.

**An address a request named is refused when it is one the network trusts.** Loopback, link-local,
and the private ranges are refused by default, because a server that fetches what it was told to
fetch is a way to reach what only the server can reach.
## Grill Log
- **Q:** Resolve a conflicting body length by preferring one field? **A:** No. _Rationale:_ a rule
  only helps when everything in the chain shares it, and the attack exists precisely because they do
  not. _Rejected:_ preferring the chunked encoding; preferring the last length.
- **Q:** Escape line breaks in a header value? **A:** No. _Rationale:_ it turns an obviously
  malicious input into a silently accepted one, and rescues no valid value. _Rejected:_ percent-
  encoding the break.
- **Q:** Treat a request that states no provenance as same-site? **A:** No. _Rationale:_ an old
  client and a hostile one look identical, and only one of the two readings is safe for both.
  _Rejected:_ trusting silence.
- **Q:** Detect an escaping path by searching for the ascent sequence? **A:** No. _Rationale:_ every
  such filter has an encoding that gets past it; walking segments has none. _Rejected:_ substring
  rejection.
- **Q:** Refuse a private address unconditionally? **A:** No — by default, with a way to permit.
  _Rationale:_ a service that genuinely must reach an internal host exists, and a refusal it cannot
  lift would be worked around outside this module, where nothing checks anything. _Rejected:_ an
  absolute prohibition.
## Referenced by
[[src/Std/_MOC]] · [[ADR-0017 What the Web Layer Refuses]] · [[Std Http Server Guard]] · [[Std Http Server]] · [[Std Http Message]]
