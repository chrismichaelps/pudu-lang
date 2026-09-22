---
type: module
path: "@root/website/src/Web/Dynamic.pudu"
fidelity: Active
tags: [website, routing, serverless]
aliases: [website Web Dynamic]
---
# Website Dynamic Routes

Dispatches `/search`, `/packages/search`, and the dynamic 404 fallback for the serverless function. It uses the same
search and missing views as the complete local router and marks missing responses against indexing.

Resolved Grill Log: Vercel serves all known canonical pages and assets from static output before this
function. Package search holds the small public project document in memory, while source and canonical package pages remain static. The bounded router therefore refuses unknown paths rather than carrying the full static route
graph into every cold start.
