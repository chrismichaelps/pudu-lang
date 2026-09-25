---
type: module
path: "@root/website/src/PlaygroundRunner.pudu"
fidelity: Active
tags: [website, playground, service]
aliases: [website PlaygroundRunner]
---
# Playground Runner Service

A standalone service (`/run`, `/assist`, `/health`) that runs programs through the bubblewrap sandbox for a site that does not run them itself. It refuses to listen beyond loopback without a token and compares the token in constant time.

Resolved Grill Log: the reader name the site sends is believed only on a request that carried the token.
