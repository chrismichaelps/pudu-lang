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

Inside a string, an interpolation's `{expression}` is coloured as the code it
is, braces and all, while `\{` and `\}` stay escapes of the text around it.

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
| Hover | the signature the checker *inferred*, plus the doc comment; an imported name shows its module's documentation |
| Go to definition | the resolver's symbol identity, into the imported module's file for an imported name or an import path |
| References, rename, highlights | the resolver's symbol identity, never spelling |
| Completion | members of the receiver's type, a module's exports after `Q.`, whole module paths and selections in imports, a match arm's variants, a record literal's unset fields, and the names in scope |
| Signature help | the called function's parameters, with the active one marked |
| Inlay hints | the types the checker inferred for bindings |
| Semantic tokens | the lexer and resolver, so a name is coloured by what it is |
| Outline, breadcrumbs, workspace symbols | every documented declaration, with its signature |
| Code actions | `pudu fmt`, offered as a fix-all when the file is not formatted |
| Format document | `pudu fmt`, applied as one edit |

Hover shows what the compiler concluded, not what was written down: an
unannotated function still has a signature, and an annotated one is shown as it
was *understood*.

Completion opens on its own after `.`, and after `{` or `,` where a list of
names is being written — an import's selection or a record literal's fields.
Anywhere else a brace opens a block and a comma separates arguments, so nothing
is offered there until asked for.

## Commands and settings

- **Pudu: Restart Language Server** stops the running server and starts the
  configured one — what you want after rebuilding the compiler. Changing
  `pudu.serverPath` restarts it too.
- `pudu.serverPath` — the compiler to run as `<path> lsp`.
- `pudu.trace.server` — `messages` or `verbose` logs the traffic between the
  editor and the server to the **Pudu** output channel.

## Limits

Synchronisation is full-document. Incremental edits are not accepted, because
the server would be applying a range it has no guarantee it can interpret.
While an edit is analysed the server keeps reading, so a newer edit replaces an
older one still waiting and a cancelled request stops its work.
