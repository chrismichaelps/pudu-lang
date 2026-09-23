---
type: module
path: "@root/src/Pudu/Lsp/Analysis.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
tags: [module, medium, tooling, lsp]
aliases: [Lsp Analysis]
---

# LSP Analysis

## Purpose

Compile one open document as the program it is — under the module source root its own path and
module name give it — and gather everything the editor features read from that compile.

## Interface

```haskell
analyse            :: Text -> Text -> IO Analysis             -- uri, text
analyseIn          :: FilePath -> Text -> Text -> IO Analysis -- source root, uri, text
analyseOver        :: Map FilePath Text -> FilePath -> Text -> Text -> IO Analysis  -- open buffers first
documentSourceRoot :: [FilePath] -> Text -> Text -> IO FilePath  -- workspace folders, uri, text
fileUriPath        :: Text -> Maybe FilePath
pathOf             :: Text -> Text
```

### Governance

- **A document is rooted as the command line roots it.** A file that declares its module is
  rooted by `sourceRootFor` ([[Compiler Program]]): its path with the module's segments taken off
  the end. `workspace/src/App/Main.pudu` declaring `App.Main` is rooted at `workspace/src` whatever
  folder the editor opened, and a module its path does not name is rooted at its directory, as
  `pudu check` does. The header is read from the tokens of the document's first lines, so it is
  found while the rest does not parse.
- Each document is rooted on its own. Two programs in one workspace, each with its own `Lib`, never
  read each other's modules.
- Workspace folders say which files the session owns; they root only a file with no header yet (the
  most specific folder holding it, else the nearest directory with a project marker within a few
  levels, else its own directory) and a document that is not a file (the first folder, else the
  working directory).
- `analyseIn` keeps the parser's recovered tree only when the root did not parse, and gathers the
  program's sum and record shapes, declared methods, and export index once per analysis.
- `analyseOver` compiles with the other open documents' text in place of the disk, and records
  every module file the program read — transitive imports included — as `analysisDependencies`.
- A `file:` URI is percent-decoded as UTF-8; any other scheme is not a path.

### Linkage

- **Requires:** [[Compiler Program]], [[Compiler Pipeline]], [[Lexer]], [[Lsp Context]],
  [[Lsp Documents]], [[Lsp Shapes]].
- **Consumed by:** [[Lsp Server]].

## Negative Logic (Prohibited Paths)

- Do not use a workspace folder as the module source root of a file that declares its module.
- Do not share one source root between documents that belong to different programs.

## Grill Log

- **Q:** Why derive the root per document instead of trusting the workspace root? **A:** An editor
  opens whatever folder the reader chose — a repository, a parent of `src`, a folder of several
  programs. _Rationale:_ the file and its declared module are the only facts that say where its
  program's modules are, and they are what the command line uses. _Rejected:_ the workspace root as
  source root, which made imports disappear whenever the folder was not exactly the source root.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]]
