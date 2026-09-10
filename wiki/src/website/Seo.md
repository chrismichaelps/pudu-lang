---
type: module
path: "@root/website/src/Seo.pudu"
fidelity: Active
tags: [website, seo, sitemap, metadata]
aliases: [website Seo]
---
# Website Seo

Builds route-specific title, description, canonical, robots, Open Graph, Twitter, and JSON-LD head
nodes. It also renders the root robots policy and an XML sitemap from the generated catalogue.
The about page carries `AboutPage` data for Pudu and its author; the author's profile identities
are the same fixed destinations shown to readers.

Search pages are `noindex,follow`; canonical content pages are `index,follow`. The sitemap contains
only unique canonical home, guide, about, donation, module-index, module, and symbol-family URLs.
Symbol paths include the declaration kind to remain distinct on case-insensitive filesystems. It uses absolute UTF-8 URLs and
stays one file while the catalogue remains below 50,000 URLs.

## Grill Log

- **Q:** Add every search query to the sitemap? **A:** No. _Rationale:_ query combinations create
  duplicate thin pages and unbounded crawl space. _Rejected:_ indexing internal search results.
- **Q:** Block search in robots.txt as well as using `noindex`? **A:** No. _Rationale:_ a crawler
  must fetch the page to read `noindex`. _Rejected:_ conflicting crawl and index controls.
- **Q:** Add hreflang? **A:** Not until a translated canonical page exists. _Rationale:_ hreflang
  must identify real alternates, not planned translations. _Rejected:_ speculative language tags.

Resolved Grill Log: metadata describes visible content, canonical URLs agree with the sitemap, and
generated records—not request text—define indexable API pages.
