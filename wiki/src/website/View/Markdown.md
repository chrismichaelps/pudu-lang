---
type: module
path: "@root/website/src/View/Markdown.pudu"
fidelity: Active
tags: [website, view, documentation, markdown]
aliases: [website View Markdown]
---
# Website View Markdown

Turns a documentation page's Markdown lines into a `Document { title, summary, blocks, headings }`.
The subset is the one the documentation is written in: `#`–`####` headings, paragraphs, fenced code
with a language, `-`/`*` and numbered lists, `>` quotations, pipe tables with a separator row, and
`---` rules. Inline markup inside a line is [[website View MarkdownInline]]'s.

The first `# ` heading is the page title rather than a block, because the page shows it above the
article. Every other heading receives an anchor made from its words — lower-case letters and digits
with single dashes — made distinct with `-2`, `-3` when a page repeats a heading, and is listed in
`headings` for the page's contents. The summary is the first paragraph line with its markup removed,
used as the page's description.

Every piece of text becomes a text node through `Std.Html.Build`, so nothing a page says can become
markup. The website suite checks that a script written in prose is escaped, that repeated headings
get distinct anchors, and that tables render.

Resolved Grill Log: a general Markdown engine was rejected; the documentation needs a known subset,
and a parser that accepts everything also accepts raw HTML, which would reopen escaping. The parser
reads each line once and closes pending paragraphs, lists, and quotations when a line of another
kind arrives.
