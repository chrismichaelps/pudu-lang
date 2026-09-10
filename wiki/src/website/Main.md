---
type: module
path: "@root/website/src/Main.pudu"
fidelity: Active
tags: [website, entrypoint]
aliases: [website Main]
---
# Website Main

Loads configuration and the generated catalogue, constructs routes, starts `Std.Http.Server`, and
owns listener cleanup. It contains composition only; search and HTML remain below the web edge.

Resolved Grill Log: fail before binding when catalogue or configuration is invalid; always stop a
listener that started.
