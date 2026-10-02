---
type: moc
tags: [moc, module, frontend]
---

# Frontend Module Map

- [[Token]] — closed keyword/symbol vocabulary with lossless token and trivia values.
- [[Lexer Facade]] — total public tokenization and diagnostics boundary.
- [[src/Pudu/Frontend/Lexer/_MOC|Lexer modules]] — strict traversal plus modular trivia, identifier, number, symbol, and quoted scanners.
- [[Macro Expansion]] — hygienic expansion of macro calls before name resolution.
- [[Syntax]] — untyped recovery-capable surface API.
- [[src/Pudu/Frontend/Syntax/_MOC|Syntax modules]] — located values, segmented names, and the recursive data-only tree.
- [[Parser]] — public parsing boundary producing a recovered module and its diagnostics.
- [[Parser Derive Spec]] — derive syntax, structural duplicates and bounded recovery evidence.
- [[src/Pudu/Frontend/Parser/_MOC|Parser modules]] — strict bounded state plus name, type, pattern, expression, import, binding, block, function, generic, type-declaration, trait, and orchestration grammar.

## Referenced by

[[src/Pudu/_MOC]] · [[Frontend]]
