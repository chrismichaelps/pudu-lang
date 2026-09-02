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
## Referenced by
[[src/Std/_MOC]] · [[ADR-0017 What the Web Layer Refuses]] · [[Std Http Safe]] · [[Std Http Server]] · [[Std Http Server Route]]
