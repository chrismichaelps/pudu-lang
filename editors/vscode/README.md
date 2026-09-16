# Pudu for VS Code

Diagnostics, hover, go to definition, an outline, completion, and formatting —
all answered by the compiler itself.

## What it is

The extension is a thin client. Everything it shows comes from `pudu lsp`,
which is the same binary that runs `pudu check`, `pudu doc`, and `pudu fmt`.
That is deliberate: an editor and a command line that disagree about what a
program means is worse than an editor that says nothing, and a second analyser
written for the editor would drift from the first within a release.

## Versions

The extension's version changes whenever what it ships changes. An editor
decides whether to replace a build it already holds by comparing versions, so
shipping new contents under a version already installed leaves every editor
that has it showing the old one.

## The file icon

A `.pudu` file carries the language's own mark, so a project's files are
distinguishable at a glance in the explorer rather than all wearing the same
blank page. The icon is contributed by the language rather than by a file icon
theme, which means it appears whatever theme the reader has chosen — a theme
that names its own icon for `.pudu` still wins, which is correct, because that
is the reader's choice rather than ours.

## Highlighting

The grammar's keyword list is taken from the compiler's own token table rather
than kept by hand, so a keyword the language gains does not go unhighlighted
until somebody notices. Beyond keywords it separates the things a reader
distinguishes: the name a declaration introduces from the keyword introducing
it, a constant from a control keyword, and — because this is the difference the
language exists to make explicit — checked arithmetic from its wrapping and
saturating forms, which are three different operators and read as three.

## Installing

1. Build the compiler and put it on your `PATH`:

   ```bash
   mkdir -p "$HOME/.local/bin"
   cabal install exe:pudu --installdir="$HOME/.local/bin" --overwrite-policy=always
   export PATH="$HOME/.local/bin:$PATH"
   hash -r
   test "$(command -v pudu)" = "$HOME/.local/bin/pudu"
   pudu check test-fixtures/tooling/RecentLanguage.pudu
   node test/lsp-session.mjs "$(command -v pudu)"
   ```

   Run those commands from the repository root. They replace an older installed binary and prove
   the resolved executable understands the recent language surface through a real LSP session.
   Or point the extension at a build with the `pudu.serverPath` setting.

2. From this directory:

   ```bash
   npm install
   ```

3. Press <kbd>F5</kbd> in VS Code to launch an Extension Development Host, or
   package it with `npx vsce package` and install the `.vsix`.

## What works

| Feature | Comes from |
|---|---|
| Diagnostics as you type | the ordinary compile — same codes, spans, and help as `pudu check` |
| Hover | the signature the checker *inferred*, plus the doc comment |
| Go to definition | the documentation index |
| Outline and breadcrumbs | every documented declaration, with its signature |
| Completion | every documented name, with its signature and documentation |
| Format document | `pudu fmt`, applied as one edit |

Hover shows what the compiler concluded, not what was written down: an
unannotated function still has a signature, and an annotated one is shown as it
was *understood*.

## What does not work yet

Rename, find references, workspace symbols, and semantic tokens. The server
does not announce these, so VS Code keeps offering its own text-based fallback
rather than showing an empty result.

Synchronisation is full-document. Incremental edits are not accepted, because
the server would be applying a range it has no guarantee it can interpret.
