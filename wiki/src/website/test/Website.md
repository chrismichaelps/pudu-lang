---
type: module
path: "@root/website/src/Test/Website.pudu"
fidelity: Active
tags: [website, tests, regression]
aliases: [website regression suite]
---
# Website Regression Suite

Loads the generated public catalogue and checks ranked search, canonical server-rendered pages,
robots policy, sitemap coverage, favicon metadata, about, donation and repository navigation, copyright,
same-name declaration families, missing-page behavior, and hostile query escaping.
It also round-trips the compact dynamic search format and compares ranked results from the full and
compact catalogues.
The shell checks one search landmark, icon-free header navigation, a labelled native mobile disclosure,
current-page state, and the new code-first home sections.
Invocation checks include Vercel's outer `Action: Invoke` envelope with its request encoded in `body`.
Documentation checks load `website/docs` and require every page in order, the index, a page's anchored
sections, code blocks, contents, previous and next links, its sidebar mark, a 404 for an unknown page,
the `/guide` canonical address, and sitemap coverage. A page must name its author and version, link
its own Markdown source, label its code by language, and carry the folded narrow-screen page list.
The library index must be sectioned, say what a module is for, show child modules beneath their family,
and leave no module unplaced; home must link a new reader to the introduction. The Markdown renderer is checked directly: the
title stays out of the body, a script in prose is escaped, a `javascript:` target is not a link,
repeated headings get distinct anchors, and tables render.

The `@alice/json-kit` snapshot exercises catalog, search, profile, overview, install command, source, docs, releases, sitemap, missing routes, binary file preview, encoded filename, and immutable GitHub source link.
It checks linked package rows and the shared banner across documentation, API, download, release,
about, support, search, and missing pages.
A seven-project synthetic catalogue checks the most-starred group and the complete list.
The package fixture checks the framed search view, compact declaration matches in the dynamic
function, native ticket and contribution lists and detail pages, escaped discussion Markdown,
initial discussion headings, unknown-number refusal, and sitemap paths. A JSON-only fixture
proves the compact dynamic loader starts without release trees.
Synthetic 25-record catalogues and conversations prove the first page is bounded, the next page
contains the remaining rows, and file icons resolve locally. The three-state checks require
bordered empty banners for an unpublished catalogue, no search matches, and no tickets; loaded
lists expose their state and include a hidden live loader for the next bounded request. The 404
banner names the missing page.
Avatar checks cover the preferred local GitHub copy, the GitHub image URL fallback, and the
two-tone owner mark when an owner has no usable image.
Search checks cover the live script hook, both routers serving `/packages/suggest` JSON, a signature
search listing its declaration with a kind mark, a project page's fixed search box, and a filter that
searches inside one project (no project rows, declarations from that project only) in both local and
serverless routes. Ranking itself is checked in [[website package search suite]]. The avatar checks
cover the two-tone mark beneath a missing image.

Resolved Grill Log: tests call the pure route renderer rather than opening a socket, so failures
identify website behavior and do not depend on a free local port.
Search checks assert rank position and exclusion for module intent, explicit scope, exact names,
multi-term text, and generic-renamed Pudu type shapes. The exact-name check queries `crc32`, a name
no module shares: a query that is also a module's last name segment ranks that module's declarations
first by design, so such a query cannot isolate the exact-name rule.
Documentation prose is checked on `Std.List.any`, whose `## Examples` and `## See also` sections must
render through the shared Markdown pipeline as anchored headings, a code block, and a list.
The rendered result page must expose the query syntax it accepts.
The catalogue gate also requires every public declaration to carry at least one documentation line,
including implementation members whose text is inherited from their trait contract.

Since #367 its dynamic fixtures carry `LivePackages.offline()`, so they exercise the snapshot path; the live path is covered by [[website live packages suite]].
