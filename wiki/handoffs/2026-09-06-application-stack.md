---
type: handoff
status: IMPLEMENTED_UNVALIDATED
tags: [handoff, stdlib, application]
---
# Application Stack Integration

The user redirected work from backend optimization to the enterprise application stack, with
Spring Boot / C# web application capabilities as the reference. Preserve LSP work and leave it
outside this assignment. Existing concurrent compiler refactors and LSP changes remain owned
by their authors. The broad application objective remains incomplete.

Language Architect → STD Implementer. Own Std.App.Database typed query/transaction helpers and
Std.Http.Server.Reply typed HTML/JSON responses, mirrors and navigation. No tests, builds, reviews
or measurements, per user direction. Commit only this scope directly to dev.

Deliver queryAll/queryOne/queryOptional with structured query-versus-mapping errors; expose the
existing driver transaction boundary from the application resource. Provide page/view/jsonValue
response helpers through the existing HTTP serialization path.

Exact next action: connect these APIs in a runnable database-backed HTML and JSON application
example with explicit configuration, routes and startup/shutdown ordering.

## Referenced by
[[handoffs/_MOC]] · [[Std App Database]] · [[Std Http Server Reply]]

## Runnable application composition

STD Implementer owns examples/web/Notes.pudu and its mirror, example readmes and HTTP Message
UTF-8 length correction. Implemented HTML listing, JSON read/create routes, parameterized writes,
SQLite/PostgreSQL placeholder selection and database-before-schema startup. LSP remains untouched.
No tests, builds, reviews or measurements run.
Exact next action: add browser form submission and typed redirect responses, sharing validation
and parameterized persistence with the JSON create route.

## Page ergonomics

User requested a simpler page definition. STD Implementer owns Html.Compose and its mirror,
Notes layout and navigation. Added fluent persistent content and extracted noteView. No parser
changes or raw-template interpolation. No tests, builds or reviews.
Exact next action: use the composition API for browser create/edit forms sharing validation
and database operations with JSON handlers.

## Server rendering ownership

STD Implementer owns Html fragment rendering, Html.Ssr, Reply.rendered and mirrors. Implemented
static plans, typed slots, per-render reuse and bounded accepted UTF-8 output. Output remains
buffered; limits do not bound peak allocation. No tests, builds, reviews or measurements.
Exact next action: integrate application-owned prepared plans into Notes routes and add HTTP
conditional response handling with explicit private/public cache policy.

## Enterprise configuration and mail boundary

STD Implementer owns App numeric admission and configurable request limits, Mail validation and
serialization, mirrors and deployment contract. LSP changes remain untouched. No testing or
reviews performed. Universal deployment and enterprise readiness remain unproven.
Exact next action: implement bounded concurrent request admission with configurable deadlines
and draining, keeping it independent of provider-specific request adapters.

Implemented shared request read deadlines and bounded delimiter admission. Own Net.Read, Server
and App integration plus mirrors. No tests, builds or reviews.
Exact next action: bounded worker admission and response-write deadlines; handler cancellation
and full shutdown deadlines remain outstanding.

Implemented response write deadlines, including fallback responses, and documented poor-network
priorities. Own Server/App fields, copy helpers and mirrors. No tests, builds or reviews.
Exact next action: bounded worker admission and cleanup on thread-start failure, with explicit
backpressure rather than unbounded worker accumulation.

Implemented fixed connection workers and bounded queue with configuration admission. Own Server,
App and mirrors. LSP untouched. No tests, builds or reviews.
Exact next action: cap keep-alive requests per connection and make handler chain construction
once per worker rather than once per request, preserving middleware order.

Worker handler composition now occurs once per worker, preserving middleware order.
The user requested “Threats in STD”; clarification between threads and security threats is pending.
Exact next action: implement the clarified STD feature, retaining server worker limits.

User clarified threads/concurrency. Implemented Std.Concurrent.parallelBounded and
forEachBounded with atomic claiming and joining all started tasks. Own Concurrent and mirror.
Exact next action: add typed result collection for bounded parallel mapping, retaining input
order independently of completion order. No tests, builds or reviews run.
