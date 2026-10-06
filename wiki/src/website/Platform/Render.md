---
type: module
path: "@root/website/src/Render.pudu"
fidelity: Active
tags: [website, render, command]
aliases: [website Platform Render]
---
# Website Platform Render

Renders one URL target through the same Pudu router used by the local server, tests, and static
capture, loading the catalogue and the documentation pages first. It remains a diagnostic command surface rather than a Vercel adapter.

Resolved Grill Log: keep one-request rendering bounded and reuse `Web.Routes`; do not duplicate route
or view decisions in command tooling.

Renders through [[website App Static]] with the batch loggers of [[website App Logging]], whose events
go to standard error so the response envelope on standard output stays intact.
