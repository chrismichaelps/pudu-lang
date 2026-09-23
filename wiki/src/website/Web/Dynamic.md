---
type: module
path: "@root/website/src/Web/Dynamic.pudu"
fidelity: Active
tags: [website, routing, serverless]
aliases: [website Web Dynamic]
---
# Website Dynamic Routes

Dispatches `/search`, `/packages/search`, `/packages/suggest`, and the dynamic 404 fallback for the serverless function. It uses the same
search and missing views as the complete local router and marks missing responses against indexing.
Package search accepts a page query so scroll loading fetches only the next bounded result page.
An optional project filter searches inside one project and persists across search pages.
`/packages/suggest` answers the suggestion box from the same compact documents, through the same
reply the local router uses, so the function imports no static-page routes.

Resolved Grill Log: Vercel serves all known canonical pages and assets from static output before this
function. Package search holds the small public project document in memory, while source and canonical package pages remain static. The bounded router therefore refuses unknown paths rather than carrying the full static route
graph into every cold start.
