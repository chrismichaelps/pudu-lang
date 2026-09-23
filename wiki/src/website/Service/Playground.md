---
type: module
path: "@root/website/src/Service/Playground.pudu"
fidelity: Active
tags: [website, playground, service]
aliases: [website Service Playground]
---
# Website Playground Service

Chooses the runner from configuration — `off`, `local` (the sandbox on this machine), or a runner's URL — and exposes `run` and `ask`. `remembering` keeps repeatable outcomes by the SHA-256 of action and program; questions are never remembered. `gatesFor` builds separate admission gates for runs and questions.

Resolved Grill Log: the runner is a record of functions because each constructor closes over its own settings; calls go through a local binding so method dispatch cannot pick a same-named module function.
