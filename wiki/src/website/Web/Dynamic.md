---
type: module
path: "@root/website/src/Web/Dynamic.pudu"
fidelity: Active
tags: [website, routing, serverless]
aliases: [website Web Dynamic]
---
# Website Dynamic Routes

Dispatches only `/search` and the dynamic 404 fallback for the serverless function. It uses the same
search and missing views as the complete local router and marks missing responses against indexing.

Resolved Grill Log: Vercel serves all known canonical pages and assets from static output before this
function. The bounded router therefore refuses unknown paths rather than carrying the full static route
graph into every cold start.
