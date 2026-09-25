---
type: script
path: "@root/website/public/assets/packages/pagination.js"
fidelity: Active
tags: [website, packages, asset]
aliases: [Package list pagination]
---
# Package List Pagination

Imports the shared avatar failure handler so catalogue and profile pages reveal their neutral
placeholder when a GitHub image cannot load. It binds the handler to rows fetched on later pages
after appending them to the live document, so their image load state is meaningful.

Enhances bounded server-rendered package, handle, search, ticket, and contribution lists. An
intersection observer fetches the next same-origin HTML page near the scroll edge and appends
only list rows from every named list on the page. The next-page anchor remains a working navigation control when script, scrolling,
or a request fails.
It marks lists busy while a request is pending, shows a spinner with live loading text, and restores
the loaded state when the request resolves. An error keeps the next-page link available.
When the next-page link has keyboard focus, it stays visible during the request. On the last page,
focus moves to the first appended result before the link is removed.

See [[architecture/PACKAGES]] · [[website View Packages Catalog]] · [[website Package Discussion]].

## Grill Log

- **Q:** Fetch every record at the first request? **A:** No; render one page and request the next
  only as needed. _Rationale:_ large histories and catalogues keep first-page responses bounded.

Resolved Grill Log: subsequent pages are ordinary URLs and the browser enhancement never owns
the only route to more results.
