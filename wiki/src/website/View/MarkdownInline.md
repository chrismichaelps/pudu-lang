---
type: module
path: "@root/website/src/View/MarkdownInline.pudu"
fidelity: Active
tags: [website, view, documentation, markdown]
aliases: [website View MarkdownInline]
---
# Website View MarkdownInline

Renders one line of Markdown prose: `` `code` ``, `**strong**`, `*emphasis*`, and `[label](target)`
links, with everything between them as text. A plain run is taken up to the next marker in one step.
A marker with nothing to close it is kept as the character it is, so a stray asterisk does not
swallow the rest of a line.

A link is made only when its target is a path, a fragment, or an `http`/`https` address. Any other
target — a `javascript:` address written as a link — is refused and the text is shown as written; the
website suite checks it.

Resolved Grill Log: underscore emphasis was left out, because identifiers such as `snake_case` are
common in documentation and would otherwise turn into emphasis mid-word.
