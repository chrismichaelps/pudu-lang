---
type: module
path: "@root/tools/pudu-js/bridge.test.mjs"
fidelity: Active
aliases: [Pudu JS Bridge Test]
tags: [module, test, desktop, javascript]
---
# Pudu JS Bridge Test

Runs [[Pudu JS Bridge]] in an isolated context with a recorded `fetch`: JSON and binary invocation
with the invoke key, null for empty answers, typed rejection from an envelope, an unreadable body
and a transport failure, listeners and `once`, a throwing listener that does not stop others,
ordered channel delivery and closing with the channel in its header, `emit` as the reserved
command, forwarded development errors with their position, and a frozen bridge without its key.

## Referenced by

[[Desktop Webview Gate]] · [[Desktop Webview CI]]
