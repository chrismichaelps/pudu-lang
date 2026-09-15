---
type: module
path: "@root/website/src/View/Layout.pudu"
fidelity: Active
tags: [website, view, html]
aliases: [website View Layout]
---
# Website View Layout

Builds the shared typed-HTML document shell, masthead, search form, navigation, metadata, and footer.
The document advertises the supplied short Pudu logo as its browser icon. Navigation exposes the
documentation, API, about page, and donation page; the repository remains in the footer without an icon in the
header. Mobile pages use a native disclosure immediately followed by the same navigation links, while
desktop pages show the direct link row. The footer names the copyright holder on every page. Static style
references carry a revision so browser and CDN caches change with this visual system.

Documentation pages and API symbols share the `/docs/` prefix, so the current-page mark is decided by
depth: `/docs`, `/guide`, and a path one segment below `/docs/` are the documentation; three segments
below it are a symbol and mark the API link.

Resolved Grill Log: use supplied logos and a white reading surface; keep all request text escaped;
keep external destinations visible, fixed, and outside request-controlled data.
Keep one search form in the page body, preserve logical keyboard order, announce the current page, and
use native disclosure semantics so the mobile menu works without client JavaScript.
