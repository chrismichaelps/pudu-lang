---
type: module
path: "@root/src/Pudu/Format/Spacing.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.55
depth_status: MEDIUM
coupling: 1.5
interface_stability: 0.9
tags: [module, medium, tooling]
aliases: [Format Spacing]
---

# Format Spacing

## Purpose

Own token piece definitions, line classification (brace styles, prefix vs binary operators), and whitespace spacing rules for the Pudu code formatter.

## Interface

```haskell
data Piece
  = TokenPiece !Token
  | CommentPiece !Text

data Shape = Shape
  { shapeBrace  :: !BraceStyle
  , shapePrefix :: !Bool
  }

data BraceStyle = Record | Selection | Block

attachedBrace :: BraceStyle -> Bool
paddedBrace   :: BraceStyle -> Bool

classify       :: [Piece] -> [Shape]
prefixKinds    :: [Piece] -> [Bool]
braceKinds     :: [Piece] -> [BraceStyle]
unaryOperators :: [SymbolKind]
openers        :: [SymbolKind]
closers        :: [SymbolKind]
isSymbol       :: TokenKind -> SymbolKind -> Bool
render         :: Piece -> Text
wantsSpace     :: Shape -> Shape -> Piece -> Piece -> Bool
spaced         :: [Piece] -> Text
```

## Governance

- **Two adjacencies tokens alone cannot decide:**
  1. Record construction (`User{id: 1}`, tight) vs block (`if ready { 1 }`, padded) vs import selection list (`import Std.Num {Add}`, detached, unpadded).
  2. Ambiguous unary prefix operators (`!`, `-`, `&`, `~`, `*`, `..`) vs binary operators.
- Both decisions are classified once per line before spacing is resolved, ensuring a closing brace is spaced according to the brace it closes rather than adjacent tokens.
- Whitespace is strictly computed without modifying token sequence or lexemes.

## Linkage

- **Requires:** `Pudu.Frontend.Token`.
- **Consumed by:** `Pudu.Format`.

## Negative Logic (Prohibited Paths)

- No line layout or indentation tracking; those belong to `Pudu.Format`.
- No AST parsing or typing.

## Grill Log

- **Q:** Why extract piece classification and spacing into `Pudu.Format.Spacing`? **A:** The token spacing rules, brace style disambiguation, and operator classification form an independent, pure decision boundary (~260 lines), reducing `Pudu.Format` to a concise coordinator (~240 lines) focused on line layout and indentation.
