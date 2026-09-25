---
type: module
path: "@root/website/src/View/Layout.pudu"
fidelity: Active
tags: [website, view, html]
aliases: [website View Layout]
---
# Website View Layout

Builds the shared typed-HTML document shell, masthead, search form, navigation, metadata, and footer.
The document advertises the Pudu "P" mark as its icon at sizes search engines accept: `/favicon.ico`
(16, 32, and 48 pixels) and PNGs of 48, 96, and 192 pixels, every one a multiple of 48 as Google's
search results require. It also links a 180-pixel touch icon on white, the web manifest
`/site.webmanifest` (192 and 512 pixels), and a `theme-color`. Navigation exposes the
documentation, API, about page, and donation page; the repository remains in the footer without an icon in the
header. Mobile pages use a native disclosure immediately followed by the same navigation links, while
desktop pages show the direct link row. The footer names the copyright holder on every page. Static style
references carry a revision so browser and CDN caches change with this visual system.
Revision `50` is the banner-headed, ink-on-soft-blue system: typographic page headers, the package ledger, the
package search box and its suggestions, two-tone owner marks, native discussions, and data states.
Every page with a header opens with `banner`, including package search results, owner profiles, and
project pages. `banner` owns the
label, one page title, lead, and optional actions or metadata; `page-banner` uses its reading-page
variant while home and catalogue use the full height.

Documentation pages and API symbols share the `/docs/` prefix, so the current-page mark is decided by
depth: `/docs`, `/guide`, and a path one segment below `/docs/` are the documentation; three segments
below it are a symbol and mark the API link.

- **Q:** Link the packages from the masthead? **A:** Always, as Packages. _Rationale:_ `/packages` always answers, with an empty state before any package is published.
- **Q:** Maintain separate heading markup on each public page? **A:** No; share the banner component with a compact variant. _Rationale:_ one title hierarchy and visual language carry through public reading pages.

Resolved Grill Log: use supplied logos and a white reading surface; keep all request text escaped;
keep external destinations visible, fixed, and outside request-controlled data.
Keep one search form in the page body, preserve logical keyboard order, announce the current page, and
use native disclosure semantics so the mobile menu works without client JavaScript.
