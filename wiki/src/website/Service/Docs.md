---
type: module
path: "@root/website/src/Service/Docs.pudu"
fidelity: Active
tags: [website, service, documentation]
aliases: [website Service Docs]
---
# Website Service Docs

Loads the language documentation: every `.md` file in one directory, in the order their names give,
as `Page { slug, title, lines }` values. A file is named `NN-slug.md`; the number orders the pages
and is left out of the address, so a page can move without its address changing. The title is the
first `# ` heading. `find` answers the page at an address and `neighbours` the pages before and
after it.

The service knows files and text, not HTML: turning a page's lines into markup belongs to
[[website View Markdown]]. Pages are loaded once, before any request, beside the API catalogue; an
unreadable directory or an empty one is `DocsUnreadable` and stops the site from starting.

Resolved Grill Log: a table of contents file was rejected in favour of the ordering number, because
two files that must agree drift and a page added without its table entry would be invisible.
Parsing was kept out of the service so the dependency rule in [[architecture/WEBSITE]] holds.
