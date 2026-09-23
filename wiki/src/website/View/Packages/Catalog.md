---
type: module
path: "@root/website/src/View/Packages/Catalog.pudu"
fidelity: Active
tags: [website, packages, view]
aliases: [website View Packages Catalog]
---
# Website Package Catalog

Renders `/packages` with the shared search banner, keyword links, and linked project rows. Each row
shows the owner, name, description, latest release, and stars. A catalogue with more than six projects
first shows six most-starred projects, then the full list; smaller catalogues show only the full list.
Search results use the same rows. `/@handle` shows a copied GitHub profile and that handle's projects
in the row style.
The submitted search view uses a focused white result panel with a large query field, package rows
first, and public declaration matches from generated package API catalogues beneath them. Each
declaration links to its package's Docs tab. Search remains server-rendered and no-index.
Catalogue, handle, and search lists show one bounded page at a time. Numbered catalogue and handle
URLs, and the search query's page parameter, provide a fallback when automatic scroll loading is
unavailable. Project and declaration matches each advance in bounded pages, so a broad search
does not silently hide later declarations.
The catalogue and search results show an explicit empty banner when no data exists; populated
lists carry the loaded state, and the next-page control includes an accessible loading status.

See [[architecture/PACKAGES]] · [[website Service Packages]].

## Grill Log

- **Q:** Answer 404 at `/packages` before any package exists? **A:** No; the banner and an empty state with the three commands that publish a package (name it `@owner/repo`, `pudu login`, `pudu release 0.1.0`). _Rationale:_ the masthead links it, and a reader looking for packages learns how to add the first.

Resolved Grill Log: query results are not indexed, while canonical catalogue and handle pages are generated from the public snapshot. Topic links filter the list instead of repeating packages on the catalogue.
The most-starred group is a discovery aid on a larger catalogue; the complete list remains explicit
and deterministically ordered by the snapshot.
Search results use the site's own palette and type system while keeping the reference image's dense,
scannable alignment; they are not a second package data source.
