---
type: module
path: "@root/src/Pudu/Lsp/Definition.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.35
depth_status: SHALLOW
tags: [module, shallow, tooling, lsp]
aliases: [Lsp Definition]
---

# LSP Definition

## Purpose

Map the name under an editor cursor to the declaration indexed for that document.

## Interface

```haskell
definitionAt :: Text -> Analysis -> Int -> Json
```

## Governance

- Definition lookup uses the resolver's symbol identity at the cursor and maps that symbol's span to
  the compiler-built declaration index; equal spelling is never identity.
- Missing words and declarations answer null; no location is guessed.

## Algorithm

Find the resolved declaration or reference at the cursor, select the indexed declaration containing
that symbol's defining span, and render its document location.

## Negative Logic (Prohibited Paths)

- No parsing, filesystem search, cross-document guessing, or mutation.

## Grill Log

- **Q:** Search files when the index has no match? **A:** No. _Rationale:_ the loaded compiler graph
  is authoritative; guessing by text can jump to a different declaration. _Rejected:_ workspace
  text search fallback.
- **Q:** Pick the first declaration sharing the cursor word? **A:** No. _Rationale:_ lexical
  shadowing gives equal text different identities. _Rejected:_ text-only definition lookup.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]]
