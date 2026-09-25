---
type: module
path: "@root/website/src/View/Packages/Highlight.pudu"
fidelity: Active
tags: [website, packages, view, highlighting]
aliases: [website View Packages Highlight]
---
# Website Package Highlight

`tokens` splits one line of Pudu into runs: `//` comments to the end of the line, text literals with
escapes, numbers, the reserved words of [[grammar/pudu]] (`KEYWORDS`), capitalised type names, and the
name after `fn`; everything else is plain. `line` renders a line as `tk-*` spans, or as plain text for
other languages.

See [[website View Packages Source]].

## Grill Log

- **Q:** Parse the file with the compiler? **A:** No; a line tokenizer. _Rationale:_ it colours what a reader scans and cannot fail on a file the compiler would reject. _Rejected:_ embedding the front end in the site.

Resolved Grill Log: per-line lexical colouring; no semantic claims.
