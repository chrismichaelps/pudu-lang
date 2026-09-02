---
type: module
path: "@root/lib/Std/Http/Server/Socket.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, http, websocket, live]
aliases: [Std Http Server Socket]
---
# Std Http Server Socket
## Purpose
A connection that stays open and carries messages both ways, and the check that decides who may open
one.
## Interface
Whether a request is asking to change to a lasting connection, and from where. The answer that
agrees to it, built only from a request that was permitted. What a message is: text, bytes, a
goodbye, or a check that the other end is still there. Reading a frame from bytes and writing one.
The bound on how large a message may be. The refusals, and what each says.
## Governance and algorithm
**The origin is checked on the upgrade, and there is no way to skip it.** This is the decision that
matters most in this module and the one most often missed. A lasting connection is not subject to
the rule that stops one site reading another's answers — a page on any site can open one to any
server, and it carries the viewer's cookies when it does. So a server that upgrades whoever asks has
given every site on the internet an authenticated connection to it, and the viewer sees nothing. The
permitted origins are a parameter of the upgrade rather than a step that can be omitted, and a
request whose origin is not among them is refused before anything is agreed to.

**A message from the far end is refused unless it is masked, and a message to it is never masked.**
That is what the protocol requires, and the requirement is not decorative: the masking is what stops
a crafted message being read as a request by something between the two ends that does not understand
this protocol.

**How large a message may be is bounded before it is read.** A length field says how much is coming,
and a reader that believes it has been told how much memory to allocate by whoever is sending. The
bound is checked against the stated length, not against what arrives.

**A close carries a reason where there is one.** A connection that stops answering and one that
ended are indistinguishable to the other end otherwise, and it cannot tell either from a line being
cut.

**The handshake's digest is not a secret and is not treated as one.** It proves the far end followed
the protocol rather than that it knows anything, which is why the algorithm the protocol names is
acceptable here and nowhere else in this library.
## Grill Log
- **Q:** Make the origin check optional, since some clients are not browsers? **A:** No.
  _Rationale:_ a non-browser client sends no origin, which is a different case and is handled; making
  the check optional means the browser case is unprotected wherever somebody left it off, and that
  is the case where the attack exists. _Rejected:_ an optional origin allowlist.
- **Q:** Accept an unmasked message from the far end, since this end knows what it means? **A:** No.
  _Rationale:_ what is between the two ends may not, and that is the reason the requirement exists.
  _Rejected:_ tolerating unmasked frames.
- **Q:** Read a frame and then check its size? **A:** No. _Rationale:_ by then the memory has been
  allocated, which is the whole of the attack. _Rejected:_ checking after reading.
- **Q:** Reassemble a message split across frames? **A:** Yes, up to the same bound, which applies to
  the message rather than to each piece. _Rationale:_ a bound per frame is not a bound: enough
  frames make any size. _Rejected:_ a per-frame limit only.
## Referenced by
[[src/Std/_MOC]] · [[Std Http Server]] · [[Std Crypto]] · [[Std Ui Live]] · [[ADR-0017 What the Web Layer Refuses]]
