---
type: module
path: "@root/website/src/Main.pudu"
fidelity: Active
tags: [website, entrypoint]
aliases: [website Main]
---
# Website Main

Loads configuration, the generated catalogue, and the Markdown documentation pages, constructs routes,
starts `Std.Http.Server`, and owns listener cleanup. It contains composition only; search and HTML remain below the web edge.

Resolved Grill Log: fail before binding when catalogue or configuration is invalid; always stop a
listener that started.

## Application and logging

Assembles [[website App Static]] once, serves its routes with [[website Web Access]] as middleware,
and writes its startup events through [[website App Logging]]. Settings too wrong to build a logger
from are still written plainly to standard error.
