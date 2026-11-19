---
type: module
path: "@root/test/fetch-server.mjs"
fidelity: Active
tags: [module, test, native, mobile, network]
aliases: [Test Fetch Server]
---

# Test Fetch Server

## Purpose and interface

Local HTTP server for the Remote app's simulator run. `node test/fetch-server.mjs <record>` listens on `127.0.0.1` on an ephemeral port. It writes its port to the file named by its argument at start, and rewrites that file after every request with the counts so far. [[iOS Simulator Run]] starts it through `withFetchServer` and reads the counts after the app exits.

Counts, as JSON: `port`, `profile`, `limited` and `revalidated`.

## Routes

- `/profile`: answers 200 with the body `profile body`, an `ETag` of `"v1"` and `Cache-Control: no-cache`. A request whose `If-None-Match` is `"v1"` is answered 304 and counted in `revalidated`.
- `/limited`: answers 429 with `Retry-After: 1` on its first request, then 200 with the body `limited body`.
- Any other path: 404.

## Invariants

- The counts are written after every request, including a 404, so the file never lags behind what was served.
- The server holds no state beyond the counts and the limited route's first-request flag.

## Negative Logic

- No authentication, no TLS and no bind beyond the loopback address.
- No other content types or sizes. The routes exist only to exercise the table's rules.

## Dependencies and consumers

Node built-ins only. Used by [[iOS Simulator Run]] through `withFetchServer`, and by the Remote example [[Native Remote Example]].

## Resolved Grill Log

- **Q:** Why count revalidations on the server? **A:** The platform's protocol cache is the component that revalidates. Only the server can show that the conditional request was sent and answered 304.
- **Q:** Why write the counts after every request? **A:** The simulator run reads the file after the app exits, so every served request must already be recorded.

## Referenced by

[[src/_MOC]] · [[iOS Simulator Run]] · [[Native Remote Example]]
