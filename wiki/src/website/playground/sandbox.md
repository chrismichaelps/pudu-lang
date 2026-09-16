---
type: module
path: "@root/website/playground/sandbox.sh"
fidelity: Active
tags: [website, playground, security]
aliases: [website playground sandbox]
---
# Playground Sandbox

Runs one program, formatting, or language-server session. Every run is `pudu run --confined`. Isolation `bwrap` adds namespaces, a read-only system, and a private `/tmp`; `confined` (a serverless function) and `none` (a developer machine) give an emptied environment and resource limits with the runtime's confinement. Exit 125 means isolation was refused.

Resolved Grill Log: the runtime's confinement is kept even under bubblewrap, so a sandbox misconfiguration never widens what a program may do.
