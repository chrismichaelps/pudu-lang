---
type: moc
tags: [moc, module, frontend, lexer]
---

# Lexer Module Map

- [[Lexer Cursor]] — strict snapshot-safe traversal, capture, emission, and completion state.
- [[Trivia Scanner]] — exact whitespace, line comments, nested block comments, and E0003 recovery.
- [[Identifier Scanner]] — Unicode name boundaries and closed keyword classification.
- Numeric, symbol, quoted scanners, and the public facade enter through later dependency-ordered issues.

## Referenced by

[[src/Pudu/Frontend/_MOC]] · [[Frontend]]
