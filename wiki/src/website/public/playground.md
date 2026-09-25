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

Completion is asked for after a name's character and `.`, after the space that follows `import` or `case` — a module path or a variant is chosen there, not a new name — and after `{` or `,` where the caret is inside an import's selection or a record literal's braces. The brace and comma are sent to the server as the request's trigger, and it answers them only where a list of names starts. An item's `textEdit` replaces its whole range, so a module path accepted after `import Std.Bytes.Cu` replaces the path rather than doubling it; its `filterText` is what typing is matched against, and its `sortText` is the server's order. A function accepted inside an import's selection is named, not called.

Resolved Grill Log: the trigger check for `{` and `,` is made in the page before asking, because each question starts a language server in the sandbox; the server's own check is what decides. Modules are served individually from `/assets/playground/*module` with `no-cache`, because relative imports carry no version; only lower-case dashed names ending in `.js` are served.

The page names every module with a `modulepreload` link (`View.Playground.SCRIPT_MODULES`, which the playground suite checks against this folder), so all of them are fetched at once beside `main.js` instead of one import level per round trip. The page also draws the splitter column and Run's shortcut hint; `bindSplitter` adopts the drawn handle and gives it its role and keys, and `showShortcut` corrects the keys for the platform, so mounting the island changes no element's size or position.
