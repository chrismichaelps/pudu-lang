---
type: moc
tags: [moc, module]
---

# Module Map

- [[Pudu Cabal Manifest]] — package components and explicit runtime module registration.

- [[src/Pudu/_MOC|Pudu modules]] — validated source, diagnostic, lexical-vocabulary, and strict-cursor foundations.
- [[src/Std/_MOC|Standard library modules]] — mirrored Pudu modules shipped under `Std`.
- [[src/cbits/_MOC|Native boundary modules]] — the libffi bridge and test-only C++ conformance
  surface.

## Depth Baseline

| Status | Count | Modules |
| --- | ---: | --- |
| DEEP | 3 | [[Lexer Cursor]], [[Parser State]], [[Parser Expression]] |
| MEDIUM | 17 | [[Source]], [[Diagnostic Model]], [[Token]], [[Lexer Facade]], [[Trivia Scanner]], [[Identifier Scanner]], [[Number Scanner]], [[Symbol Scanner]], [[Quoted Scanner]], [[Syntax]], [[Syntax Located]], [[Syntax Name]], [[Syntax Tree]], [[Parser Name]], [[Parser Type]], [[Parser Import]], [[Parser Binding]] |

## Referenced by

[[00-INDEX]] · [[grammar/haskell]]
