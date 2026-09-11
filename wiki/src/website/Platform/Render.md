---
type: module
path: "@root/website/src/Render.pudu"
fidelity: Active
tags: [website, render, command]
aliases: [website Platform Render]
---
# Website Platform Render

Renders one URL target through the same Pudu router used by the local server, Lambda function, tests,
and static capture. It remains a diagnostic command surface rather than a Vercel adapter.

Resolved Grill Log: keep one-request rendering bounded and reuse `Web.Routes`; do not duplicate route
or view decisions in command tooling.
