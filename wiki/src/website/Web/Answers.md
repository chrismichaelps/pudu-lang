---
type: module
path: "@root/website/src/Web/Answers.pudu"
fidelity: Active
tags: [website, http, mediator]
aliases: [website Web Answers]
---
# Website Web Answers

Turns a mediator outcome into a response. A page is `200`; `NotFound` and `NotYetListed` are the
caller's missing page; `Invalid` is a no-index `400` page listing what was wrong; `Unavailable` is
`503`; any other failure is a `500` page that names no internals. Both routers use it, each passing
its own missing page.

Resolved Grill Log: one translation from application failures to HTTP, so a new failure is handled
everywhere at once. _Rejected:_ handlers answering responses (the application would depend on HTTP).
