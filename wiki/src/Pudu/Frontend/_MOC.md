---
type: moc
tags: [moc, module, frontend]
---

# Frontend Module Map

- [[Token]] — closed keyword/symbol vocabulary with lossless token and trivia values.
- [[Lexer Facade]] — total public tokenization and diagnostics boundary.
- [[src/Pudu/Frontend/Lexer/_MOC|Lexer modules]] — strict traversal plus modular trivia, identifier, number, symbol, and quoted scanners.
- [[Syntax]] — untyped recovery-capable surface API.
- [[src/Pudu/Frontend/Syntax/_MOC|Syntax modules]] — located values, segmented names, and the recursive data-only tree.
- [[src/Pudu/Frontend/Parser/_MOC|Parser modules]] — strict bounded state plus segmented-name and unresolved-type grammar; later modules enter dependency-first.

## Referenced by

[[src/Pudu/_MOC]] · [[Frontend]]
