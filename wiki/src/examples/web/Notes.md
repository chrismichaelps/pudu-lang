---
type: module
path: "@root/examples/web/Notes.pudu"
fidelity: Active
tags: [module, example, application]
aliases: [Notes Web Application]
---
# Notes Web Application

## Purpose and interface

A database-backed HTML and JSON service using the public application framework. `main` discovers
configuration, prepares a database resource, registers database then schema stages, and runs App.
The default SQLite file persists notes; PostgreSQL can be selected through DATABASE_URL. Only
the two bundled placeholder styles are admitted. A fixed CREATE TABLE IF NOT EXISTS statement
runs after opening the client. This demonstrates bootstrap schema creation, not schema migrations.

GET / renders escaped note titles and bodies; GET /api/notes returns typed JSON. POST /api/notes
requires application/json (optional media parameters), an object with nonempty title at most 200
characters and body at most 10000 characters, and binds both values as parameters. Titles are
unique; write failures return a generic 500 without exposing driver text. Bad media gives 415,
malformed JSON 400 and invalid fields 422. Read failures give a generic 503. Requests do not
implicitly initialize the database. App orders startup and reverse teardown.

## Grill Log

- **Q:** Share a SQL statement across dialects by interpolating input? **A:** No; only fixed
  placeholders differ. User text always travels in Driver.Value parameters.
- **Q:** Claim production readiness? **A:** No; this is an unvalidated runnable example, with no
  authentication, pagination or deployment TLS configuration. Bind loopback by default.
- **Q:** Render database text as trusted HTML? **A:** No; construct Html.text nodes and encode
  JSON through the standard model.

## Dependencies and consumers

[[Std App Database]] · [[Std Http Server Reply]] · [[Std Http Message]] · [[Std Db Row]]

## Referenced by
[[src/_MOC]] · [[2026-09-06-application-stack]]

## Linear page composition

HTML routes use [[Std Html Compose]] to build a linear heading/paragraph/repeated-component
chain. noteView is an ordinary reusable function. Document boilerplate lives in the composition
module; no nested arrays are required in the page handler. Escaping remains in Std.Html.
Resolved Grill Log: Keep database failure handling separate from successful page composition
with an early return, so the layout is readable independently of query control flow.
