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
  , shapeClosingBar :: !Bool
  }

data BraceStyle = Record | Selection | Block

attachedBrace :: BraceStyle -> Bool
paddedBrace   :: BraceStyle -> Bool

classify       :: [Piece] -> [Shape]
prefixKinds    :: [Piece] -> [Maybe Bool] -> [Bool]
braceKinds     :: [Piece] -> [BraceStyle]
lambdaBars     :: [Piece] -> [Maybe Bool]
unaryOperators :: [SymbolKind]
openers        :: [SymbolKind]
closers        :: [SymbolKind]
isSymbol       :: TokenKind -> SymbolKind -> Bool
render         :: Piece -> Text
wantsSpace     :: Shape -> Shape -> Piece -> Piece -> Bool
spaced         :: [Piece] -> Text
```

## Governance

- A macro call is written **tight**: `twice!(20)`, `timed!({ work() })`. `!` is never an operator
  after an operand, so a name followed by `!` is always a call's name and bang; and a block handed
  to a call opens against its parenthesis. Without these two rules the formatter spelled every call
  `twice !(20)` and `timed !( { ... })`.

- A range is written **tight**, both ends and either end absent: `0..n`, `0..=n`, `items[2..]`,
  `items[..2]`. It reads as one value that way, which is what it is.

- `|` is spelled three ways — the operator that joins two values, the separator between a sum's
  variants and a pattern's alternatives, and the pair holding a function literal's parameters. The
  first is told by what precedes it, since an operator follows a value and a literal's bar does not.
  The other two cannot be, because both appear where no value precedes them, so **what follows
  decides**: a parameter list holds value names — including Unicode names admitted by the lexer —
  and continues with a bar, a comma, or a type annotation, while a variant or an alternative names
  a capitalised constructor. The closing bar is found as the partner of the opening one, because on
  its own it is spelled exactly like the operator.

- A brace in **pattern position** — after `let`, `var`, `const`, `case`, a field's colon, or an
  opening delimiter — holds its fields tight like the record construction it matches. Opened by a
  keyword it keeps the space that separates it from the keyword, which is the pair of answers an
  import's selection list already gives.

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
