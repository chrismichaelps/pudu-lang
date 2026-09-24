---
type: module
path: "@root/website/src/View/MarkdownHtml.pudu"
fidelity: Active
tags: [website, view, packages, markdown, security]
aliases: [website View MarkdownHtml]
---
# Website View MarkdownHtml

Reads the HTML a package README writes, such as a centred logo or a row of links, and rebuilds it
from an allowlist. `opensBlock` answers whether a line starts an HTML block: `<` followed by an allowed
tag name, a closing tag, or a comment. `render` turns the block's text into nodes.

| Kept | Rule |
| --- | --- |
| Elements | `p`, `div`, `span`, `a`, `img`, `br`, `strong`, `em`, `b`, `i`, `code`, `sub`, `sup`, `h1`–`h4` |
| Attributes | `href` on `a`; `src`, `alt`, `width`, `height` on `img`; `title` on either; `align` on any kept element |
| `align` | `left`, `center`, or `right` becomes the class `md-align-<value>`; the attribute itself is not written |
| `width`, `height` | digits only |

Any other element is dropped with its tags while its text stays. `script`, `style`, `iframe`,
`object`, `embed`, `template`, `noscript`, `textarea`, `title`, `svg`, and `math` are dropped with
everything inside them. Comments are dropped. `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&#39;`, and `&nbsp;`
are decoded, and every piece of text becomes a text node through `Std.Html.Build`, so nothing a README
says can become markup.

`Targets { pages, files }` says where a relative target points. `resolve` answers a web address or
a place on the page unchanged: `http://`, `https://`, `/`, or `#`. A relative path, with a leading
`./` removed, is joined to `pages` for a link or to `files` for an image. Any other target, including
`javascript:`, `data:`, `vbscript:`, a path climbing with `..`, and any relative path when the prefix
is empty, is refused: a link loses its `href` and an image is dropped. `none()` refuses every
relative target; the documentation uses it.

An unclosed element is closed at the end of the block, and a closing tag with no open element of
its name is ignored.

See [[website View Markdown]] · [[website View MarkdownInline]] · [[website View Packages Project]].

## Grill Log

- **Q:** Render README HTML at all, when [[website View Markdown]] refused raw HTML to keep escaping
  closed? **A:** Yes, rebuilt from an allowlist rather than passed through. _Rationale:_ READMEs
  written for GitHub centre logos and link rows in HTML, and showing the tags as text makes a
  package look broken. Every kept element is rebuilt by `Std.Html.Build` from a fixed name, fixed
  attribute names, and checked values, so escaping stays closed. _Rejected:_ passing HTML through,
  which is script injection on the site's origin; dropping HTML blocks, which loses the logo and
  links.
- **Q:** Where does a README's relative image load from? **A:** The release's tag on
  `raw.githubusercontent.com`. _Rationale:_ the release is a tag of the repository the package is,
  so the image is the published one; nothing a package ships is served from the site's own origin,
  so a hostile SVG cannot run there. _Rejected:_ a route on the site serving package files as
  images.
- **Q:** Why refuse `..` in a relative target? **A:** A README's links stay inside the package's own
  pages and files; `..` could only climb out of them.
