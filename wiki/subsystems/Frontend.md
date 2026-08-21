---
type: subsystem
tags: [subsystem]
aliases: [Frontend]
---

# Frontend

## Purpose

Transform [[Source Text]] into a faithful recovery-capable syntax representation and ordered lexical/syntactic [[Diagnostic]] values without applying type or ownership policy.

## Owns

Lexer · parser · tokens · trivia · source spans · untyped syntax · recovery nodes.

## Active Modules

[[Token]] defines the closed lossless vocabulary. [[Lexer Cursor]] owns strict traversal; [[Trivia Scanner]], [[Identifier Scanner]], [[Number Scanner]], and [[Symbol Scanner]] provide modular categories beneath the final quoted scanner and facade.

## Boundaries

- Receives immutable source-domain values.
- Exposes syntax and diagnostics to [[Semantics]].
- Has no runtime, backend, filesystem, or process dependencies.

## Grill Log

- **Q:** Should trivia be discarded? **A:** No; preserve it for formatting and diagnostics while keeping semantic token traversal separate. _Rationale:_ reparsing source for tools creates drift. _Rejected:_ semantic-only tokens.
- **Q:** Should parser recovery synthesize plausible program meaning? **A:** No; synthesize explicit missing/error nodes only. _Rationale:_ later phases can suppress cascades without accepting guessed code. _Rejected:_ silent token insertion with no provenance.

## Referenced by

[[architecture/OVERVIEW]] · [[Semantics]] · [[Tooling]] · [[Token]] · [[Lexer Cursor]] · [[src/Pudu/Frontend/_MOC]]
