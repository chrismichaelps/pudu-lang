---
type: module
path: "@root/website/src/View/Docs.pudu"
fidelity: Active
tags: [website, view, documentation]
aliases: [website View Docs]
---
# Website View Docs

Renders the documentation. `index` lists every page as a card with its summary; `page` renders one
page in a three-column layout: the list of pages, the article, and the page's own contents.

- **Sidebar.** A `<details>` element that starts open. On a wide screen its summary is hidden and the
  list simply sits beside the article; on a narrow one the summary folds the list away, with no
  script. The page being read carries `aria-current="page"`.
- **Article.** A link back to the documentation, the title, the blocks [[website View Markdown]]
  produced, and links to the previous and next pages.
- **Contents.** The page's second- and third-level headings as links to their anchors, hidden below
  1100px.

`/docs` is the index and `/docs/:page` a page; `/guide`, the address the earlier hand-written guide
used, renders the index with `/docs` as its canonical address. Page addresses are one segment below
`/docs/`, while API symbols are three, so the two never share a route. The layout was modelled on
established language documentation sites — a page list, a readable article width, and on-page
contents — without copying their wording.

Resolved Grill Log: rendering a page's contents in the article itself was rejected on wide screens,
where a separate column lets a reader jump without scrolling back to the top.
