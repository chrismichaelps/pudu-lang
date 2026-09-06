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
