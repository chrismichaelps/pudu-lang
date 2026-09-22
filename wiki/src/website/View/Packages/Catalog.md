---
type: module
path: "@root/website/src/View/Packages/Catalog.pudu"
fidelity: Active
tags: [website, packages, view]
aliases: [website View Packages Catalog]
---
# Website Package Catalog

Renders `/packages` with a Pudu-branded search banner, one compact list of all public projects, and keyword links that open filtered results. The list does not duplicate a project in a second topic section. `/@handle` shows a copied GitHub profile and that handle's public projects in the same list style.

See [[architecture/PACKAGES]] · [[website Service Packages]].

## Grill Log

- **Q:** Answer 404 at `/packages` before any package exists? **A:** No; the banner and an empty state with the three commands that publish a package (name it `@owner/repo`, `pudu login`, `pudu release 0.1.0`). _Rationale:_ the masthead links it, and a reader looking for packages learns how to add the first.

Resolved Grill Log: query results are not indexed, while canonical catalogue and handle pages are generated from the public snapshot. Topic links filter the list instead of repeating packages on the catalogue.
