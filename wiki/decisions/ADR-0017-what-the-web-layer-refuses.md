---
type: decision
status: ACCEPTED
date: 2026-09-02
tags: [decision, stdlib, http, security, web]
aliases: [ADR-0017-what-the-web-layer-refuses]
---

# ADR-0017: What the Web Layer Refuses

## Context

A web framework's security posture is decided by its defaults, because the failures it is judged on
are not the ones somebody chose. They are the ones nobody chose: a header written from a value that
happened to contain a line break, a body length taken from the second of two conflicting fields, a
redirect to wherever the query string said, a stack trace returned to a stranger because an
exception escaped. Each of those is a default, and in most frameworks the safe version is available
and off.

The specific list is not guesswork. The industry catalogue names access control, misconfiguration,
injection, cryptographic failure, and — added in the most recent revision — the mishandling of
exceptional conditions, which is the category that covers an error page saying too much. Alongside
it, a maintained set of response headers exists for exactly the failures a page cannot defend
against by itself: being framed, being sniffed into a different content type, leaking a URL through
a referrer, being loaded across origins that should not have it.

Two further observations shaped this. The first is that the established defence against cross-site
request forgery has moved: the browser now states the provenance of a request in a header it will
not let a page forge, which is a stronger primitive than a token a page has to carry and a server
has to store. The second is that a widely deployed framework discloses its own identity and version
in ordinary response headers, and the catalogue of headers to strip is mostly a list of frameworks
that did this.

## Decision

Every judgement below is made in one place, as a pure function on values, and the server calls it
rather than each program remembering to.

**A message states its body length once or it is refused.** A request carrying both a length and a
chunked encoding, or two lengths that disagree, is not a request with an ambiguity to resolve — it
is a request built to be read differently by two things in a chain. There is no resolution rule
because adopting one is how the two readers come to disagree. It is refused.

**A header value that could end the header is refused, not escaped.** A carriage return or line feed
in a header name or value is rejected where the message is rendered. Escaping would be a guess about
what the sender meant; there is no legitimate value containing one.

**The protective headers are sent by default and turned off deliberately.** Framing denied, sniffing
denied, referrer withheld, a policy that permits only the page's own origin and forbids objects and
frames, cross-origin isolation, and no store. A program that needs a laxer setting says so, and that
is one line in its source rather than the absence of one.

**Nothing identifies the framework.** No name, no version, in any header, ever — not configurable,
because there is no benefit to disclosing it and the disclosure is what turns a published advisory
into a targeted request.

**Provenance is checked before a token is.** A state-changing request whose stated origin is another
site is refused. The token pattern remains available for the cases the header does not cover, but it
is a second line rather than the first, because a defence the browser enforces cannot be forgotten
by a page author.

**A cross-origin permission names its origins.** There is no wildcard together with credentials, and
no reflecting whatever origin asked. An allowlist is the only form offered, because the reflecting
form is indistinguishable from no policy and is what a misconfiguration looks like.

**A redirect goes somewhere the program named.** A target is a path within this site or an origin on
a stated list. A target taken from a request and used unchecked is how a trusted domain is borrowed
to make a phishing link look real.

**A path from a request cannot leave the directory it is resolved under.** Resolution is done by
walking segments and refusing to ascend past the root, rather than by looking for a suspicious
substring — every filter of that kind has an encoding that gets past it.

**A failure tells the caller that it failed and nothing else.** The detail goes to the program's own
log, where it is useful; what crosses the network is a status and a sentence. The identifier tying
the two together is in both, so an operator handed one can find the other.

## Consequences

A program is secure in these respects before its author has thought about any of them, and becomes
less so only by writing a line that says to. That is the inversion this decision is for.

The cost is real and worth stating: defaults this strict break things. A policy permitting only the
page's own origin breaks an inline script; denying framing breaks a legitimate embed; withholding
the referrer breaks an analytics report. In every one of those cases the program's author learns at
the first test and writes one line. The alternative arrangement — permissive by default, tightened
later — fails silently and is discovered by someone else.

## Alternatives Rejected

**Resolving a conflicting body length by a stated precedence.** Rejected: a rule only helps if
everything in the chain has the same one, and the attack exists precisely because they do not.

**Escaping line breaks in header values rather than refusing them.** Rejected: it converts an
obviously malicious input into a silently accepted one, and there is no valid value it rescues.

**A single switch that turns the protections on.** Rejected: a switch has an off position, and
whether it is on becomes a property of a deployment rather than of the code. These are on.

## Validation

Each refusal has a check that supplies the attack and asserts the refusal — a request framed two
ways, a header value carrying a line break, a redirect aimed off-site, a path climbing out of its
root, a cross-site form post — and a companion check asserting that the legitimate version of the
same thing is still accepted, because a defence that also refuses ordinary traffic has not been
tested.

## Referenced by

[[Std Http Safe]] · [[Std Http Server Guard]] · [[Std Http Message]] · [[Std Http Server]] · [[ADR-0016 An Application Is a Value]]
