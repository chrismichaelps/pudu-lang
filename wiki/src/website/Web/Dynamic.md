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

## Live package routes (#367)

`Dynamic` carries a [[website Service LivePackages]] overlay. `/packages`, `/packages/page/:page`,
`/packages/search`, and `/packages/suggest` answer from the snapshot with GitHub laid over it, and
`/@owner/repo`, `/@owner/repo/releases`, and `/@owner` answer for packages the build has not seen
(they arrive through the platform fallback because no static file exists). A path without `@` stays
missing. Package answers carry `public, max-age=0, s-maxage=120, stale-while-revalidate=86400` when
GitHub contributed and `s-maxage=30, stale-while-revalidate=600` when only the snapshot did; a
missing package is cached 60 s so a new publication is not hidden for long.

Resolved Grill Log: the CDN absorbs reader traffic and revalidates in the background, so a function
instance asks GitHub at most once per freshness window; an arbitrary `@owner/repo` never causes a
GitHub request because only the merged index is consulted.

## Every package page (#367, step 1)

Requests under `/@` reach `packagePage`, which consults the merged index once, then dispatches
[[website Web PackagePages]] with `LivePackages.detail` as the tab filler. A `200` carries the live
(`s-maxage=300, stale-while-revalidate=86400`) or snapshot (`s-maxage=60, stale-while-revalidate=600`)
policy; any refusal carries `MISSING_CACHE` (`s-maxage=60`) and `noindex`.

Resolved Grill Log: the index is consulted only after a request is known to be a package page, so
playground and search requests never wait on GitHub.
