---
type: script
path: "@root/website/public/assets/packages/featured.js"
fidelity: Active
tags: [website, packages, hydration]
aliases: [Package featured hydration]
---

# Package featured hydration

Refreshes the home showcase (`View/Home.pudu`) from live data without a redeploy. Each
`.home-package[data-package]` card is rendered statically from the snapshot; this module fetches
`GET /packages/suggest?q=<name>` for each card (at most six, in parallel), reads the matching
project's `stars` and `latest` from the JSON, and replaces only the `.home-package-latest` and
`.home-package-stars` text.

## Grill Log

- **Q:** New batch endpoint or reuse suggest? **A:** Reuse `GET /packages/suggest`. _Rationale:_ the
  suggest reply already carries live `stars` and `latest` from the same merged index the listing
  uses, in both local and function routers, so no new backend surface, cache policy, or sitemap entry
  is needed. _Rejected:_ a dedicated `/packages/featured` endpoint for one page section.
- **Q:** Replace structure or text? **A:** Text only. _Rationale:_ structure stays identical for SEO
  and no-JS readers; hydration never inserts nodes. _Rejected:_ re-rendering cards from JSON.
- **Q:** What on failure? **A:** Keep snapshot text. _Rationale:_ the snapshot is the documented
  baseline and fallback; a GitHub outage must not blank the showcase. _Rejected:_ hiding cards or
  showing an error state.

Resolved Grill Log: one in-flight request per card, bounded to the showcase; stale answers cannot
replace newer ones because each card is written once from its own response; package-author text is
inserted as text only.
