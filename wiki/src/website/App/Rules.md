---
type: module
path: "@root/website/src/App/Rules.pudu"
fidelity: Active
tags: [website, application, validation]
aliases: [website App Rules]
---
# Website App Rules

`pudu-lang-validator` rules for every message a reader fills in. Search queries and package queries
are at most `MAX_QUERY` (512) characters; package filters at most `MAX_FILTER` (256); module, symbol,
document, and page names at most `MAX_NAME` (256). `registrations` attaches each validator to its kind
through `PuduLangMediator.Behaviors.Validation`, so an oversized value is answered `Invalid` before any
handler, ranking, or rendering runs, and [[website Web Answers]] turns it into a no-index 400 page.

The rules bound size only. Every value a reader could send before still answers as it did: an unknown
package filter still lists nothing, and suggestions still truncate to their own shorter limit.

Resolved Grill Log: bounds are enforced where messages enter the application, once for both routers.
_Rejected:_ truncating silently (a reader would see results for a query they did not send); a bound
inside each service (two places to keep in step).
