---
type: module
path: "@root/website/src/Function.pudu"
fidelity: Active
tags: [website, pudu, lambda, serverless]
aliases: [website Function]
---
# Website Function

Loads the generated catalogue once and serves `Web.Routes` through
`Std.Http.Server.Lambda`. It translates supported invocation event shapes into one request target
and returns status, headers, and body in the platform response envelope.

Resolved Grill Log: platform invocation changes only how a request enters Pudu; route selection,
search ranking, HTML, and response policy remain the same code used by the local server and tests.
