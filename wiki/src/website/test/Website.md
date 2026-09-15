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
the `/guide` canonical address, and sitemap coverage. The Markdown renderer is checked directly: the
title stays out of the body, a script in prose is escaped, a `javascript:` target is not a link,
repeated headings get distinct anchors, and tables render.

Resolved Grill Log: tests call the pure route renderer rather than opening a socket, so failures
identify website behavior and do not depend on a free local port.
Search checks assert rank position and exclusion for module intent, explicit scope, exact names,
multi-term text, and generic-renamed Pudu type shapes.
The rendered result page must expose the query syntax it accepts.
The catalogue gate also requires every public declaration to carry at least one documentation line,
including implementation members whose text is inherited from their trait contract.
