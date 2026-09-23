---
type: module
path: "@root/website/src/View/Packages/Catalog.pudu"
fidelity: Active
tags: [website, packages, view]
aliases: [website View Packages Catalog]
---
# Website Package Catalog

Renders `/packages` as the site banner holding the shared package search box
([[website View Packages Frame]]), then a two-column index: a ledger of projects on the left and a
side column with topics (each with its project count) and how to publish. Each ledger row shows the
owner's mark, `@owner / name` over the description, the latest release, and the star count in
aligned columns; at phone width the release column folds away. A catalogue with more than six
projects first shows six most-starred projects, then the full list; smaller catalogues show only the
full list. `/@handle` opens with an "Owner" page banner holding the display name, the owner's mark,
handle, project count, and GitHub link, then its projects as a ledger.

A submitted search renders a results page whose page banner holds the same search box and a count
line, followed by two ledgers:
matching projects, then matching declarations. Declarations are ranked by
[[website Service PackageSearch]]; each row carries its kind mark, module and name, project and
release, and signature, and links to the package Docs anchor. A `filter` parameter searches inside
one project: it lists that project's declarations only and no project rows, the count line names the
project, and the server renders a clear link for the filter. Search remains server-rendered and
no-index.

Catalogue, handle, and search lists show one bounded page at a time. Numbered catalogue and handle
URLs, and the search query's page parameter (which keeps the filter), provide a fallback when
automatic scroll loading is unavailable. Project and declaration matches each advance in bounded
pages, so a broad search does not silently hide later declarations.
The catalogue and search results show an explicit empty banner when no data exists; populated
lists carry the loaded state, and the next-page control includes an accessible loading status.

See [[architecture/PACKAGES]] · [[website Service Packages]] · [[Package live search]].

## Grill Log

- **Q:** Answer 404 at `/packages` before any package exists? **A:** No; the banner and an empty state with the three commands that publish a package (name it `@owner/repo`, `pudu login`, `pudu release 0.1.0`). _Rationale:_ the masthead links it, and a reader looking for packages learns how to add the first.
- **Q:** Keep project rows global when a filter is set? **A:** No. _Rationale:_ a filter is chosen
  from a project row to search inside that project; listing other projects beside its declarations
  contradicts the choice. Removing the filter restores the global search.
- **Q:** Cards or a ledger for the catalogue? **A:** A ledger. _Rationale:_ readers compare owner,
  name, release, and stars down a column; cards scatter those facts and invite decoration.

Resolved Grill Log: query results are not indexed, while canonical catalogue and handle pages are generated from the public snapshot. Topic links search by keyword instead of repeating packages on the catalogue.
The most-starred group is a discovery aid on a larger catalogue; the complete list remains explicit
and deterministically ordered by the snapshot. Declaration order is the search service's ranking,
shared with the suggestion box.
