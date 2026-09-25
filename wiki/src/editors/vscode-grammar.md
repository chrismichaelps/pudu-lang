---
type: module
path: "@root/editors/vscode/syntaxes/pudu.tmLanguage.json"
fidelity: Active
tags: [editor, vscode, syntax]
aliases: [VS Code Grammar]
---
# VS Code Grammar

The TextMate grammar the VS Code extension colours Pudu with before the language server answers,
and wherever it does not: comments (with `///` documentation lines scoped apart), strings and
characters, numbers with their suffixes, keywords, types, labels, constants, declarations, operators,
and foreign blocks. Semantic tokens from [[Lsp Server]] refine it once a file has been checked.

A string's `{expression}` is scoped `meta.interpolation.pudu`, with the braces as
`punctuation.section.interpolation` and the expression as embedded Pudu, so it is coloured as code
rather than as text. Braces nested inside the expression, such as a record literal, are matched so
the first `}` does not end the interpolation. `\{` and `\}` are escapes, tried before an
interpolation opens.

## Negative logic

- The grammar never decides what a program means; diagnostics and semantic colouring come from the
  server.
- A keyword the lexer reserves only to refuse (`task`, `spawn`) is still coloured as a keyword, so a
  reader sees the word is not an identifier before the diagnostic explains it.

## Grill Log

- **Q:** Colour interpolations, or leave them as string text? **A:** Colour them as embedded Pudu
  (#366). _Rationale:_ every string may interpolate, and an expression painted as text hides typos
  and makes long templates unreadable. _Rejected:_ a single interpolation scope with no inner
  patterns, which would still paint the expression as one colour.
- **Q:** How is the grammar checked? **A:** By tokenizing sample lines with the same TextMate
  engine the editor runs, covering an interpolation with a nested string, escaped braces, and a
  record literal on the next line.

## Referenced by

[[Lsp Server]] · [[src/_MOC]]
