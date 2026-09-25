---
type: module
path: "@root/website/src/View/Markdown.pudu"
fidelity: Active
tags: [website, view, documentation, markdown]
aliases: [website View Markdown]
---
# Website View Markdown

Turns a documentation page's Markdown lines into a `Document { title, summary, blocks, headings }`.
Body parsing uses the same safe blocks while retaining the first level-one heading inside the body.
`parseReadme` reads a package's Markdown file with two more things: HTML blocks through
[[website View MarkdownHtml]], and relative links and images resolved through its `Targets`. The
documentation keeps the stricter subset.
The subset is the one the documentation is written in: `#`–`####` headings, paragraphs, fenced code
with a language, `-`/`*` and numbered lists, `>` quotations, pipe tables with a separator row, and
`---` rules. A table cell keeps a pipe written `\|`, even inside code, so a table can show an
operator containing one. Inline markup inside a line is [[website View MarkdownInline]]'s.

The first `# ` heading is the page title rather than a block, because the page shows it above the
article. Every other heading receives an anchor made from its words — lower-case letters and digits
with single dashes — made distinct with `-2`, `-3` when a page repeats a heading, and is listed in
`headings` for the page's contents. The summary is the first paragraph line with its markup removed,
used as the page's description.

Every fenced block is a `figure` holding a copy button, the language as a label when it has one,
and the `pre`, with the code element classed `language-<name>`. [[website View Syntax]] paints `pudu`
and shell blocks with the playground's token classes; other languages stay plain. The copy button
ships `hidden`, and `/assets/docs/copy.js` shows it and copies the block's text, so a page read
without script never offers a button that does nothing.

Every piece of text becomes a text node through `Std.Html.Build`, so nothing a page says can become
markup. The website suite checks that a script written in prose is escaped, that repeated headings
get distinct anchors, and that tables render.

Resolved Grill Log: README HTML is read only by `parseReadme`, and only through the allowlist in
[[website View MarkdownHtml]]; the documentation has no HTML to show and keeps refusing it.
A general Markdown engine was rejected; the documentation needs a known subset,
and a parser that accepts everything also accepts raw HTML, which would reopen escaping. The parser
reads each line once and closes pending paragraphs, lists, and quotations when a line of another
kind arrives.
