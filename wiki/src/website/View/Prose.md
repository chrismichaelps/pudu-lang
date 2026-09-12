---
type: module
path: "@root/website/src/View/Prose.pudu"
fidelity: Active
tags: [website, view, documentation]
aliases: [website View Prose]
---
# Website View Prose

Turns a declaration's documentation lines into structured HTML. The exporter hands the lines over
exactly as they were written, blank lines and fences included, so this module is the single place
where they become paragraphs, examples, headings, and cross-reference lists.

## Governance and algorithm

One pass over the lines with a small amount of state: the current paragraph, the current list, and
whether a fenced block is open. A blank line closes whatever is open. A ` ``` ` line opens or closes
an example. A `## ` line becomes a section heading inside the declaration, which is `h3` because the
declaration kind already occupies `h2`. A `- ` line becomes a list item.

Inline text is split on backticks so a name written mid-sentence renders as `code`. An unclosed
backtick is kept as ordinary text rather than swallowing the rest of the sentence. Plain runs become
text nodes rather than `span` elements, so the emitted markup carries no wrapper that means nothing.

## Negative Logic (Prohibited Paths)

- No Markdown beyond the four forms above. The documentation is source-owned prose, not a document
  format, and every additional form is one more thing a comment can silently get wrong.
- No rewriting of a declaration's words. Structure is derived from layout only.
- No raw HTML passthrough: every fragment is escaped, because a doc comment is source text.

## Grill Log

- **Q:** Render each documentation line as its own paragraph, as before? **A:** No. _Rationale:_ it
  made every multi-sentence comment a column of fragments and made examples unreadable.
  _Rejected:_ a full Markdown dependency for four constructs.

Resolved Grill Log: layout decides structure, the comment decides content, and the renderer invents
neither.

## Referenced by
[[src/website/_MOC]] · [[website View Documentation]]
