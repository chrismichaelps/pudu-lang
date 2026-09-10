---
type: module
path: "@root/website/src/Render.pudu"
fidelity: Active
tags: [website, platform, vercel]
aliases: [website Platform Render]
---
# Website Platform Render

Renders one URL target through the same Pudu router used locally and writes a JSON response envelope
for a serverless platform adapter.

Resolved Grill Log: keep the platform protocol textual and bounded to one request; do not duplicate
route or view decisions in the adapter.
