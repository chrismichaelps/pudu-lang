---
type: module
path: "@root/website/public/assets/playground/main.js"
fidelity: Active
tags: [website, playground, frontend]
aliases: [website playground script]
---
# Website Playground Script

The editor is a folder of ES modules in dependency layers; a lower layer never imports a higher one:

1. `config/` — `constants.js` (every tuning value and vocabulary) and `messages.js` (every sentence shown).
2. `text/` — pure text: `positions.js` (offsets ↔ line/character, tab columns), `scan.js` (when a question is worth asking), `syntax.js` (painting).
3. `model/problems.js` — diagnostics kept in step with edits (`shiftProblems` drops a problem an edit touches and moves the rest).
4. `dom/` — node builders, Markdown for server answers, floating panels.
5. `net/` — `request.js` (deadline over the whole answer, cancellation) and `errors.js` (`RequestFailure` kinds).
6. `lsp/` — `session.js` (one pending question per kind, back-off and pause after repeated failures, 429 handling), `diagnostics.js`, `completion.js` with `completion-list.js` and `completion-rank.js`, `signature.js`, `hover.js`, and `assist.js` assembling them.
7. `editor/` — `geometry.js`, `view.js` (painted copy, gutter, current line, marks), `editing.js` (undoable edits, pairs, indentation, comments), `keys.js`.
8. `features/` — run/format, output (diagnostic places become jump buttons), examples and reset in place with history, share dialog, splitter, status.
9. `main.js` — the composition root: it registers the `playground` island mount with `window.PuduIslands`, reads its props, and ties every listener outside the island, every floating panel, and every pending question to the island's abort signal, so removing the island removes all of it and mounting again adds nothing twice.

The language server is the only source of meaning: the script decides when to ask and whether an answer still applies (an answer is kept while the reader only continues the same name), never what a name is. The editor's own edits state the character the reader typed, so an accepted completion does not reopen the list and an auto-closed `(` still asks for signature help.

Resolved Grill Log: modules are served individually from `/assets/playground/*module` with `no-cache`, because relative imports carry no version; only lower-case dashed names ending in `.js` are served.
