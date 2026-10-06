---
type: module
path: "@root/website/src/App/Messages.pudu"
fidelity: Active
tags: [website, application, mediator]
aliases: [website App Messages]
---
# Website App Messages

The site's use cases as typed `pudu-lang-mediator` kinds: a fixed page (`Screen`), declaration
search, a module page, a symbol family, a documentation page, a published document, the package
listing, package search, package suggestions, a playground run, and a playground question. Every
kind fails with `Problem`: `NotFound`, `NotYetListed` (a package page that may exist in a minute),
or `Unavailable`. `kinds()` makes each kind once; [[website App Static]] and [[website App Dynamic]]
register their own handlers for the same kinds.

Page kinds answer `Shown`: the page and its `Freshness` (`Fixed`, `Snapshot`, or `Live`), which the
function turns into its edge cache policy. Suggestions answer JSON. Runs answer `Ran` and questions
`Asked`: the playground's own outcome and how long the reader must wait, so the router keeps the
status codes and `retry-after` it always sent.

Kinds are tagged `page`, `api`, or `playground` so open components can tell them apart.

Resolved Grill Log: requests carry only what a reader sent; the state a handler reads (catalogue,
packages, playground) is captured when the mediator is built, so a request cannot ask for another
site's data. _Rejected:_ the HTTP request itself as the message (the application layer would depend
on transport details).
