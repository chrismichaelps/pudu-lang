---
type: moc
tags: [moc, module, frontend, lexer]
---

# Lexer Module Map

- [[Lexer Cursor]] — strict snapshot-safe traversal, capture, emission, and completion state.
- [[Trivia Scanner]] — exact whitespace, line comments, nested block comments, and E0003 recovery.
- [[Identifier Scanner]] — Unicode name boundaries and closed keyword classification.
- [[Number Scanner]] — textual bases, fractions, exponents, range boundaries, and E0004 recovery.
- [[Symbol Scanner]] — bounded longest-match punctuation and operators.
- [[Quoted Scanner]] — decoded strings/chars, scalar-safe Unicode escapes, and E0002/E0005–E0008 recovery.
- [[Lexer Facade]] — fixed scanner precedence, total progress, E0099 recovery, and one lossless result boundary.

## Referenced by

[[src/Pudu/Frontend/_MOC]] · [[Frontend]]
