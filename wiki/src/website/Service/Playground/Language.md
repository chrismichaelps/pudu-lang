---
type: module
path: "@root/website/src/Service/Playground/Language.pudu"
fidelity: Active
tags: [website, playground, service]
aliases: [website Service Playground Language]
---
# Website Playground Language

Writes one complete language-server conversation (initialize, open, one question, shutdown, exit) and reads the answer and the published diagnostics back from the transcript.

Resolved Grill Log: each question starts a fresh server, so any number of runners can answer with nothing to route back.
