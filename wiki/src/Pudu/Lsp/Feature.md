---
type: module
path: "@root/src/Pudu/Lsp/Feature.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
tags: [module, medium, tooling, lsp]
aliases: [Lsp Feature]
---

# Lsp Feature

## Purpose

Turn the documentation index into what an editor shows.

## Interface

The exported signatures are the module header's export list.

### Governance

- Positions convert between UTF-16 code units and scalars at the edge, once, so nothing inside the compiler has to know the protocol counts differently from the lexer. A cursor after one emoji reports character 2.
- The narrowest entry covering an offset wins a hover. A declaration's span encloses its members', so the widest match would answer every hover with the same enclosing declaration.
- `symbolAt` maps a declaration or reference span to the resolver's stable symbol identity. `entryForSymbol` then selects only the documentation entry containing that symbol's defining span, so equal spelling under shadowing cannot select another declaration.
- A hover puts the signature first and the prose second: the signature answers "what is this", and a reader who already knows why still wants it without reading past a paragraph.
- The outline is flat. The index records what a module declares; inventing a hierarchy it does not have would nest members under whichever declaration happened to enclose them by offset.
- Completion ordering is left to the client, which knows what the reader has typed.

### Linkage

- **Requires:** [[Source Text]], [[Diagnostic Model]].
- **Consumed by:** [[Language Server]].

## Algorithm

Direct structural recursion over the shape being read or written; no caching and no mutation.

## Negative Logic (Prohibited Paths)

- No compilation, no analysis, and no decision about what a program means.
- No acceptance of input the format does not admit.

## Grill Log

- **Q:** Is matching the word under a cursor sufficient for identity-sensitive features? **A:** No.
  _Rationale:_ lexical shadowing deliberately gives the same spelling multiple symbols. _Rejected:_
  first source-ordered documentation entry with an equal name.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Language Server]] · [[Tooling]]
