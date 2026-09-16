---
type: module
path: "@root/lib/Std/App/Access.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, application, authorisation, access]
aliases: [Std App Access]
---
# Std App Access
## Purpose
Make a route that decided nothing impossible to write.
## Interface
Who is asking: an identity, what they hold, and what is known about them. What a route requires:
anyone, someone, a role, every one of several, any one of several, or a judgement the program
writes. The decision a requirement reaches about a principal, and why. Routes that cannot be built
without stating a requirement, and a router built from those. Turning a denial into an answer.
Reading a principal off a request.
## Governance and algorithm
**The failure this exists to prevent is a route nobody decided about.** Broken access control is the
most common serious web defect, and the reason is not that the checks are hard — it is that a route
with no check looks exactly like a route that needs none. Nothing in the source distinguishes
"anyone may do this" from "somebody forgot".

So there is no default and no optional step. A route is built with a requirement in the same call as
its handler, and there is no way to build one without. "Anyone" is a requirement that is written,
which means it is visible in review and can be found by searching, and a route that should have been
protected is a line somebody wrote rather than a line nobody wrote.

**Not knowing who is asking and not being allowed are different answers.** A caller who has not
identified themselves can fix that; one who has and is not permitted cannot, and telling them to try
again is misleading. They are separate decisions and separate statuses.

**A denial does not say why.** The reason is recorded where it is useful and does not cross the
network: a refusal that explains which role was missing tells a stranger the shape of the
authorisation model, and doing that one route at a time is how the model is mapped.

**A requirement is a value and the decision is a pure function.** So a program's whole authorisation
model can be listed, compared, and checked without a request — including the check that matters
most, which is asking what every route requires and reading the answer.
## Grill Log
- **Q:** Make the requirement an optional step, as a middleware? **A:** No. _Rationale:_ optional is
  the whole defect. A route that skipped the step and a route that needed nothing are
  indistinguishable in the source, and the first is invisible until it is exploited. _Rejected:_ an
  authorisation middleware; a default-deny middleware that a route opts out of.
- **Q:** Default to denying, so a forgotten route fails closed? **A:** Better than defaulting to
  permitting, and still rejected. _Rationale:_ a default-deny that is discovered in production reads
  as a bug and is fixed by adding a permit, often a wider one than needed, under time pressure.
  Requiring the decision means it is made once, calmly, when the route is written. _Rejected:_ an
  implicit deny.
- **Q:** Tell a denied caller what they were missing? **A:** No. _Rationale:_ done one route at a
  time, that maps the authorisation model for whoever is asking. _Rejected:_ naming the missing role
  in the response.
- **Q:** Treat unauthenticated and unauthorised as one answer? **A:** No. _Rationale:_ one is fixable
  by the caller and the other is not, and answering the second as the first sends them round a login
  loop that cannot succeed. _Rejected:_ a single refusal.
- **Q:** Read the principal from the request here? **A:** Only from what a program put there. This
  module does not verify a token or check a password: it decides, given who someone is. Establishing
  who they are is a separate concern with separate failure modes, and folding the two together is
  how a decision ends up trusting an identity nobody proved. _Rejected:_ token verification here.
## Referenced by
[[src/Std/_MOC]] · [[Std App]] · [[Std Http Server Route]] · [[ADR-0017 What the Web Layer Refuses]] · [[architecture/WEB]]
