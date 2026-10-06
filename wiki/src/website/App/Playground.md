---
type: module
path: "@root/website/src/App/Playground.pudu"
fidelity: Active
tags: [website, application, playground]
aliases: [website App Playground]
---
# Website App Playground

The playground's commands, registered on both mediators. `RunProgram` and `AskQuestion` each pass
through an admission behavior that asks the reader's gate how long they must wait; a reader over
their allowance is answered at once with the refusal the playground always gave, and nothing runs. A
playground that runs nothing counts nothing. The handlers call [[website Service Playground]]
unchanged. A post-processor writes one information event per run with its action, result, and
elapsed time; the reader's address is never logged.

Resolved Grill Log: admission is a behavior because it decides whether the handler runs at all.
_Rejected:_ admission inside the route (each router kept its own copy); logging the reader (an
address is personal data the site does not keep).
