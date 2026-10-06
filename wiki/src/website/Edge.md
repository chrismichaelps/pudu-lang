---
type: module
path: "@root/website/src/Edge.pudu"
fidelity: Active
tags: [website, serverless]
aliases: [website Edge]
---
# Website Edge

What the serverless function serves with: the compact catalogue and its search index, the package
snapshot with the [[website Service LivePackages]] overlay, and the playground with its gates. It is
the function's counterpart of [[website Site]]: [[website Function]] loads it once per cold start and
[[website App Dynamic]] assembles the function's mediator from it.

Resolved Grill Log: the record moved out of [[website Web Dynamic]] so the application layer can
depend on the function's state without importing a router; routers depend on the application, never
the reverse.
