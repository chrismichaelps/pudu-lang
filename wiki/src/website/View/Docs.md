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

- **Sidebar.** A plain navigation list beside the article on a wide screen. Below 760 pixels it is
  hidden and the article opens with a `<details>` disclosure, closed by default, holding the same
  links, so the page being read comes first on a phone rather than below a ten-item list. No script
  is involved. The page being read carries `aria-current="page"` in both.
- **Article.** A link back to the documentation, the title, a metadata list — author, the language
  version the catalogue was generated from, and a link to the page's Markdown on GitHub — the blocks
  [[website View Markdown]] produced, and links to the previous and next pages. The index carries the
  author and version, numbers its chapters, and says that every example runs as written.
- **Contents.** The page's second- and third-level headings as links to their anchors, hidden below
  1100px. `/assets/docs/contents.js` marks the section being read with `aria-current="location"`:
  the last heading above a reading line 96px below the top of the window, or the last section once
  the page cannot scroll further. Heading positions are measured when the page's size changes — a
  `ResizeObserver` on the document — and a scroll compares its offset with them once per frame, so
  scrolling reads nothing from the layout. The mark changes colour and border only, which repaint
  without reflow. Without the script the contents are plain links.

`/docs` is the index and `/docs/:page` a page; `/guide`, the address the earlier hand-written guide
used, renders the index with `/docs` as its canonical address. Page addresses are one segment below
`/docs/`, while API symbols are three, so the two never share a route. The layout was modelled on
established language documentation sites — a page list, a readable article width, and on-page
contents — without copying their wording.

Resolved Grill Log: rendering a page's contents in the article itself was rejected on wide screens,
where a separate column lets a reader jump without scrolling back to the top. One `<details>` that
starts open was replaced by two elements because an open disclosure cannot start closed on one screen
width and open on another without a script, and a closed one hides its list on every width.
