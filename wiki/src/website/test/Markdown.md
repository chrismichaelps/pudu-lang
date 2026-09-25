---
type: module
path: "@root/website/src/Test/Markdown.pudu"
fidelity: Active
tags: [website, tests, markdown, security, responsive]
aliases: [website Markdown suite]
---
# Website Markdown Suite

Checks how a package's Markdown file renders, and the stylesheet rules that keep a package page
inside a phone's width.

- **README HTML:** a centred block keeps its image and links through the allowlist of
  [[website View MarkdownHtml]]. A relative image resolves to the release's file on GitHub and a
  relative link to the source tab. Text inside HTML stays text, and entities decode once.
- **Refusals:** a `script` element and its text, `onclick`, `style`, `javascript:` and `data:`
  targets, a `..` path, an unknown element's tags, and an image without a usable source leave
  nothing that could run.
- **Inline:** `![alt](source)` images, badges written as an image inside a link, and relative
  targets refused when a page gives no `Targets`, as the documentation does.
- **Targets:** `Frame.fileTargets` points a fixture project's files at its latest release's commit
  on `raw.githubusercontent.com`, and its pages at the source tab, per directory.
- **Painting:** every case in `website/test/fixtures/syntax.json` is painted by [[website View Syntax]]
  exactly as the playground's `syntax.js` recorded it; a shell line's comment, command words, option,
  operators, string, and variables are painted; a Pudu block uses the playground's classes, another
  language stays plain and escaped, and every block carries a hidden copy button.
- **Avatars:** a banner avatar loads eagerly with high priority, a row's lazily, and an avatar with an
  image hides the two-tone mark while it loads.
- **Stylesheet:** below 900px the overview's columns stretch instead of sizing to their content,
  README images never exceed their column, the alignment classes exist, and the install panel's
  version row wraps with its copy buttons held at their width.

See [[website regression suite]] · [[website View Markdown]].

## Grill Log

- **Q:** Why a suite of its own? **A:** [[website regression suite]] is past the 500-line limit; the
  README renderer and the page-width rules are one concern with their own fixtures.
- **Q:** How is "fits any phone" checked without a browser? **A:** By asserting the rules that
  guarantee it. A page sweep in a browser at 280–884px was done by hand for #308; the suite pins
  the rules that sweep depended on, so removing one fails here first.
