---
type: module
path: "@root/website/src/Function.pudu"
fidelity: Active
tags: [website, pudu, lambda, serverless]
aliases: [website Function]
---
# Website Function

Loads the compact generated search catalogue and public package search document once and serves `Web.Dynamic` through
`Std.Http.Server.Lambda`. It translates supported invocation event shapes into one request target
and returns status, headers, and body in the platform response envelope.
Vercel's provided runtime wraps its HTTP request as JSON text in the outer invocation's `body` field;
the reader unwraps that documented platform envelope before applying the ordinary path rules.

Resolved Grill Log: the serverless graph contains only dynamic search and not-found handling; its
package loader reads the compact project index without requiring release trees. Static
documentation is already emitted to the edge. Search ranking, result HTML, and response policy remain
shared with the local server and tests, while omitting unrelated page and asset modules from startup.

## Live packages (#367)

The function builds its `Web.Dynamic` with `LivePackages.over(LiveSource.fromEnvironment())`, which
reads `GITHUB_TOKEN` when the platform sets it. Nothing is fetched at start: GitHub is asked lazily by
the first package request and remembered per instance ([[website Service LiveSource]]).

Resolved Grill Log: start-up must not depend on GitHub; a cold start that cannot reach it still
serves the compact snapshot.
