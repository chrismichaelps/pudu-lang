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

[[Token]] defines the vocabulary; [[Lexer Facade]] exposes lossless tokenization; [[Syntax]] exposes the recovery tree. [[Parser State]] owns bounded suffix traversal, [[Parser Name]] owns segmented paths, [[Parser Type]] owns unresolved types, [[Parser Expression]] owns precedence, and [[Parser Import]] owns explicit module dependencies.

## Boundaries

- Receives immutable source-domain values.
- Exposes syntax and diagnostics to [[Semantics]].
- Has no runtime, backend, filesystem, or process dependencies.

## Grill Log

- **Q:** Should trivia be discarded? **A:** No; preserve it for formatting and diagnostics while keeping semantic token traversal separate. _Rationale:_ reparsing source for tools creates drift. _Rejected:_ semantic-only tokens.
- **Q:** Should parser recovery synthesize plausible program meaning? **A:** No; synthesize explicit missing/error nodes only. _Rationale:_ later phases can suppress cascades without accepting guessed code. _Rejected:_ silent token insertion with no provenance.

## Referenced by

[[architecture/OVERVIEW]] · [[Semantics]] · [[Tooling]] · [[Token]] · [[Lexer Facade]] · [[Syntax]] · [[Parser State]] · [[Parser Name]] · [[Parser Type]] · [[Parser Expression]] · [[Parser Import]] · [[src/Pudu/Frontend/_MOC]]
