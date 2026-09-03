---
type: architecture
tags: [architecture, web, hydration, enterprise, capabilities]
aliases: [WEB, Web Applications]
---

# Web Applications

What this library can and cannot do for a web application, asked as the questions an organisation
actually asks before it commits, and answered with a verdict rather than a claim. Three verdicts are
used and they mean exactly what they say.

- **Ready** — it exists, it is checked, and a program can rely on it now.
- **Partial** — the mechanism exists and something is missing; the gap is named.
- **Absent** — it does not exist. Where it is absent because of a decision, the decision is given.
  Where it is absent because the work has not been done, that is said instead.

Nothing here is marked ready on the strength of a design. A verdict follows a fixture.

## On hydration

The question is asked first because it is the one that decides the shape of everything else.

**What hydration is, and what it costs.** A page rendered on the server arrives as markup. For it to
become interactive, the client normally re-creates the same view a second time in the browser, walks
it against the markup that arrived, and attaches behaviour. That second render is hydration, and it
brings three costs that are structural rather than incidental.

The first is **mismatch**. The server and the client render from what each believes the state to be,
and when those disagree the resulting page is a blend of two renders. This is the largest single
category of defect in frameworks built this way, and its signature failure is not a crash — it is a
page that looks right and behaves wrongly, because the markup came from one render and the behaviour
was attached according to another.

The second is **the state crossing twice**. The state is sent once as the markup it produced, and
again as data so the client can reproduce that markup. A page therefore carries its own content
twice, and the second copy is frequently the larger.

The third is **cost proportional to the page rather than to its interactivity**. The client walks the
whole tree, including everything that will never respond to anything.

**The position taken here: there is one renderer, and mismatch is not representable.** A view is
produced on the server, from state held on the server, by the single function that is the component.
The client is never asked to reproduce it. What crosses after the first render is the difference
between two renders — computed by comparing two values, both of which the server holds — and the
client applies that difference to the markup it already has.

So there is no second render to disagree with the first. Not "mismatches are rare", not "mismatches
are caught in development": there is no second render, so there is nothing for the first to
disagree with. The state also crosses once, as the markup it produced, because nothing on the other
end needs the state in order to reproduce anything. This is the same move as the escaping decision in
[[Std Html]] — the failure is removed by making it unrepresentable rather than prevented by a rule
someone has to remember.

**What that costs, stated plainly.** State held on the server is memory per viewer, and a difference
computed on the server is a round trip per interaction that needs one. Neither is hidden and neither
is free. The mitigation is in [[Std Ui]] and it is a design choice rather than an optimisation:
which events need the far end is a property of the event, stated once by the component, so an
interaction that only needs what is already on the screen does not make the trip. A framework that
decides this per interaction on the programmer's behalf gets it wrong in one direction or the other.

**What this rules out.** An application that must keep working with the connection gone, or that must
do substantial computation in the browser, is not served by this model and is not served by this
library at all — see the rendering table below. That limit is real and is not worked around.

## Rendering and delivery

| Question | Verdict | Where it stands |
|---|---|---|
| Can it render a page on the server? | **Ready** | [[Std Html]]: a view is a value, rendered to markup. Escaping is a property of the type. |
| Can a page be built from components? | **Ready** | [[Std Ui]]: a component is a state, a view function, and an update function. Components compose. |
| Can a page be interactive without a full reload? | **Ready** | [[Std Ui Live]] holds the screen, sends the difference, and takes the event back; [[Std Http Server Socket]] carries it. |
| Is hydration mismatch possible? | **Ready** | No. There is one renderer. See above. |
| Can the language run in the browser? | **Absent** | The evaluator walks a tree; there is no code generation backend. This is a compiler project and a language decision, not a library one. Nothing here approximates it. |
| Does a page work without scripting? | **Ready** | A rendered page is markup and forms. Nothing in [[Std Html]] requires a script to display or to submit. |
| Is the markup crawlable? | **Ready** | It is markup, present in the first response. |
| Can a response be streamed as it is produced? | **Absent** | Rendering produces a complete value before anything is written. Work not done. |
| Can it call another service? | **Partial** | [[Std Http Client]]. Verified transport, a whole-chain deadline, bounded redirects and response size, transfer decoding, trusted-network refusal, and cross-origin credential stripping are covered locally and against public HTTP/HTTPS/JSON endpoints. Explicit cancellation and connection reuse are absent. |
| Client-side routing? | **Absent** | Follows the browser-execution row. |

## State and the viewer

| Question | Verdict | Where it stands |
|---|---|---|
| Where does a viewer's state live? | **Ready** | On the server, in the component value. It is a value, so it can be inspected and compared. |
| What does a viewer cost? | **Partial** | The state a component holds, and a connection once live connections exist. There is no bound on either yet. |
| What happens when the connection drops? | **Partial** | Rejoining sends a whole page rather than a difference, because what the viewer's screen shows after a drop is unknown. How long a session is kept for a viewer who may return is deliberately not decided here — see [[Std Ui Live]]. |
| Multiple tabs? | **Absent** | Follows the same design. |
| Does the back button work? | **Ready** for rendered pages, **Absent** for live ones. | A page is a URL. A live screen has no history model yet. |

## Scale

| Question | Verdict | Where it stands |
|---|---|---|
| Can it run more than one process behind a balancer? | **Partial** | For rendered pages, yes — a request carries everything needed. Once a viewer's state is on the server, that viewer is bound to that process, and nothing yet handles moving or sharing it. |
| Concurrent connections per process? | **Partial** | Each connection is served on its own worker, so one slow request does not block others. The number of workers is unbounded, which is itself a limit. |
| Is there backpressure? | **Absent** | Accepting is not tied to what is already in flight. A limit exists on how many connections are accepted in total, which is not the same thing. |
| Are request sizes bounded? | **Ready** | Head and body limits are enforced before anything is buffered. |
| Is there a deadline on a request? | **Absent** | A handler that does not finish is not interrupted. Named in [[architecture/STDLIB]] as owed. |
| Rate limiting? | **Absent** | Not written. [[Std Http Server Guard]] holds the other steps. |
| Caching, and a content network in front? | **Partial** | [[Std App Cache]] holds answers in the process and says whether one is stale, so a hot key that expires is refreshed once rather than by every request at once. Cache directives for anything in front can be set; nothing helps a program decide them. |

## Data

| Question | Verdict | Where it stands |
|---|---|---|
| A real database client? | **Ready** | [[Std Db]] and [[Std Db Session]]: PostgreSQL, authenticated, with transactions, savepoints, and pooling. |
| Are values ever placed into a statement as text? | **Ready** | No. Values cross as parameters. |
| Schema migrations? | **Ready** | [[Std Db Migrate]]. Versioned, digested, each in its own transaction, locked in the database so two processes do not both migrate. What should run is decided without a database. |
| Zero-downtime schema change? | **Absent** | Depends on migrations existing first. |
| Is a failed transaction left open? | **Ready** | A scoped transaction rolls back what failed before the connection is returned. |
| Connection limits? | **Ready** | Pools bound their count. |

## Operations

| Question | Verdict | Where it stands |
|---|---|---|
| Structured logging with levels and fields? | **Ready** | [[Std Log]]. A line is a value; formatting is a function on it. |
| Does a log line carry a request identifier? | **Ready** | [[Std Http Server Guard]] carries one in and out, keeping a value that entered at a proxy so it stays the same across services. |
| Metrics? | **Ready** | [[Std App Metrics]]. Counters, gauges, and distributions as a value, each declaring its unit, with a bound on how many label combinations one metric may have — the combination that would exceed it is refused and counted rather than evicting a series. |
| Health, separated into liveness and readiness? | **Ready** | [[Std App Health]]. They are separate types: a liveness judgement is handed a reading rather than a connection, and declaring it `comptime` makes reaching a clock or a socket a compile error rather than a review note. |
| Distributed tracing? | **Ready** | [[Std App Trace]], read by [[Std Http Server Guard]] so every service in a chain agrees which piece of work a request is part of. A header that cannot be read starts a new trace rather than refusing the request. |
| Configuration from files, environment, and arguments? | **Ready** | [[Std App Config]]. Four layers, fixed order, one spelling per key. |
| Configuration per environment? | **Ready** | Profiles select a section; the machine's own settings are never profiled away. |
| Does startup order have to be guessed? | **Ready** | No. It is a list. Stop is the reverse. |
| Does a failed start leave things running? | **Ready** | No. It unwinds what came up. |
| Graceful shutdown? | **Partial** | Stages stop in reverse and the listener closes; connections in flight are joined. Draining with a deadline is not there. |
| Zero-downtime deploy? | **Absent** | Needs draining and, for live screens, a story for connections that survive a restart. |

## Security

Answered in full by [[ADR-0017 What the Web Layer Refuses]]. In summary: request framing ambiguity
refused, header injection refused, protective response headers on by default, no framework
self-disclosure, provenance checked before tokens, cross-origin permission by allowlist only,
redirects and file paths validated, and failures that tell a caller nothing but that they failed.

| Question | Verdict | Where it stands |
|---|---|---|
| Cross-site scripting? | **Ready** | Not representable in [[Std Html]] — for text, for destinations, and for event handlers. Escaping alone covers only the first, which is where template engines stop. |
| Cross-site request forgery? | **Ready** | Provenance is checked before a token is: a state-changing request from another site, or from one that will not say, is refused. |
| Request smuggling? | **Ready** | A message that states its length two ways is refused. There is no precedence rule, so there is no difference between readers to exploit. |
| Transport security? | **Ready** | [[Std Tls]]. Verification is not a parameter. |
| Authentication? | **Ready** for password and session, **Absent** for multi-factor. | [[Std App Password]] carries the work factor it was made with, so raising it locks nobody out. [[Std App Session]] issues a new name on every change of privilege, which is the fixation defence made unforgettable rather than documented. |
| Authorisation? | **Ready** | [[Std App Access]]. A requirement is given in the same call as the handler and there is no call that omits it, so a route needing nothing and a route somebody forgot stop being the same line. A program can list what every route requires. |
| Secrets handling? | **Partial** | Settings can hold one; nothing marks it as one, so nothing stops it being logged. |
| Audit trail? | **Absent** | Not designed. |

## Everything else an organisation asks

| Question | Verdict | Where it stands |
|---|---|---|
| More than one language on the page? | **Partial** | [[Std App Locale]]: negotiation by weight, catalogues with reportable gaps, and the plural forms each language actually has. Formatting numbers and dates by locale is still absent — [[Std Fmt]] shapes values without one. |
| Accessible markup? | **Partial** | Any attribute can be written, and an image requires its description at the call. Nothing checks the rest. |
| Multi-tenancy? | **Partial** | [[Std App Access]] decides on an attribute of the principal, so a per-tenant requirement is expressible. Nothing separates tenants' data or bounds their limits. |
| File uploads? | **Ready** | [[Std Http Multipart]], reachable from the request that carried the form. Bounded while reading, and the name a sender gave a file never becomes a path — a name safe to write is a separate call a program has to ask for. |
| Background work outside a request? | **Ready** for scheduling, **Absent** for queues. | [[Std App Work]]: jobs as values, both interval kinds, no overlapping runs, and a failure recorded rather than fatal. A durable queue is still absent. |
| Feature flags? | **Absent** | A setting can stand in for one. |
| Sending mail? | **Absent** | No transport. |
| Data protection and the right to erasure? | **Absent** | A program's own concern; nothing here helps or hinders. |
| A package ecosystem to get any of this from? | **Absent** | Designed in [[architecture/PACKAGES]] and deliberately not half-built: a resolver and archive extractor that are partly there is where a supply chain is compromised. |

## What this adds up to

A service that renders pages, talks to PostgreSQL, is configured properly, starts and stops in a
known order, and refuses the ordinary web attacks by default is buildable today and is a real thing
to be able to say.

An enterprise application in the full sense is not, and the gaps that matter most are named above
rather than glossed: authorisation, migrations, an authentication story, deadlines and backpressure,
and a way to obtain anything not in this library. Those are the queue, roughly in that order.

## Referenced by

[[architecture/STDLIB]] · [[ADR-0016 An Application Is a Value]] · [[ADR-0017 What the Web Layer Refuses]] · [[Std Ui]] · [[Std Html]]
