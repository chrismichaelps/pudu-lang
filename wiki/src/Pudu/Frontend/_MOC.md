---
type: moc
tags: [moc, module, frontend]
---

# Frontend Module Map

- [[Token]] — closed keyword/symbol vocabulary with lossless token and trivia values.
- [[Lexer Facade]] — total public tokenization and diagnostics boundary.
- [[src/Pudu/Frontend/Lexer/_MOC|Lexer modules]] — strict traversal plus modular trivia, identifier, number, symbol, and quoted scanners.
- Syntax and parser modules enter history only through their dependency-ordered issues.

## Referenced by

[[src/Pudu/_MOC]] · [[Frontend]]
