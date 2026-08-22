---
type: module
path: "@root/src/Pudu/Frontend/Parser.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.79
depth_status: DEEP
coupling: 3.0
interface_stability: 1.0
tags: [module, deep]
aliases: [Parser]
---

# Parser

> `{-| @Program.Parser.Module — recovers structured surface programs -}`

## Purpose

Provide the public parser façade coordinating [[Parser State]] and [[Parser Declaration]]. Detailed grammar remains in the focused modules under [[src/Pudu/Frontend/Parser/_MOC]].

## Interface

### Signatures

```haskell
data ParseResult = ParseResult
  { parseModuleValue :: !(Maybe Module)
  , parseDiagnostics :: ![Diagnostic]
  }
  deriving stock (Eq, Show)

parseModule :: Source -> [Token] -> ParseResult
```

### Governance

- Input is the lexed [[Source]] plus its token list. [[Parser State]] normalizes the stream to exactly one canonical source-end EOF, so a missing or foreign EOF is corrected structurally rather than diagnosed or crashed on.
- Parser diagnostics use E1xxx codes and the narrowest unexpected/missing token span.
- Recursive descent handles declarations/control constructs; precedence climbing handles expressions.
- Recovery synchronizes at declaration starters, `}`, and EOF while consuming at least one token after an error unless already at a valid boundary.
- Parsing does not reject type, name, ownership, null-context, or effect errors.

### Linkage

- **Requires:** [[Source]], [[Parser State]], [[Parser Declaration]], [[Token]], [[Syntax]], [[Diagnostic Model]], [[grammar/pudu]], [[grammar/haskell]].
- **Consumed by:** [[Compiler Pipeline]], [[Semantics]], formatter and LSP tooling.

## Algorithm

1. Normalize/run tokens through [[Parser State]].
2. Invoke [[Parser Declaration]] `parseCompilationUnit`.
3. Return diagnostics in the stable order [[Parser State]] produces at completion.
4. Return the recovered module separately from diagnostics; validity is decided by [[Compiler Pipeline]].

## Negative Logic (Prohibited Paths)

- No semantic name/type checks or constant evaluation.
- No context-dependent reinterpretation of keywords as identifiers.
- No unchecked indexing or incomplete pattern matches.
- No discarding tokens silently during recovery.
- No precedence encoded in scattered mutually recursive functions; keep one table/function.

## Edge Cases

- Empty input reports missing module header but terminates.
- Missing `}` at EOF yields one primary diagnostic and a block spanning available content.
- Trailing commas are accepted in imports, calls, parameters, and type arguments.
- Canonical syntax omits semicolons: statements are delimited by line breaks and braces, and continuation is decided from the operator token's preserved trivia, as resolved in [[grammar/pudu]] and implemented by [[Parser Block]] and [[Parser Expression]].
- Chained comparison/equality follows declared associativity; non-associative combinations produce a later semantic/style diagnostic if syntactically representable.
- Recursion depth is limited by a configurable internal safety budget and produces E1099 rather than overflowing the host stack.

## Depth

DEPTH 0.79 (DEEP). One surface hides a modular parser family, state/recovery mechanics, and deterministic result construction. The façade remains below 80 lines.

## Grill Log

- **Q:** Parser generator or hand-written recursive descent? **A:** Hand-written recursive descent plus precedence climbing. _Rationale:_ actionable diagnostics/recovery and evolving grammar outweigh generator compactness. _Rejected:_ opaque generated parser tables; parser combinator dependency before profiling.
- **Q:** Stop at first syntax error? **A:** No; recover at explicit boundaries with poison nodes. _Rationale:_ editor/tooling usability. _Rejected:_ fail-fast parser; speculative repair that changes meaning.
- **Q:** How does newline-delimited syntax separate expression statements? **A:** A line break ends a statement unless the previous line ends with a binary operator or the next line begins with `.`, `?`, or `.await`; the decision reads the operator token's own leading trivia. _Rationale:_ it delimits statements exactly as [[grammar/pudu]] requires without inserting terminator tokens or breaking lossless reconstruction. _Rejected:_ automatic semicolon insertion; newline tokens in the stream; construct-completeness heuristics, which leave line-initial unary operators ambiguous.
- **Q:** Implement the full proposal in the first parser patch? **A:** No; AST and parser grow through semantic vertical slices, and unsupported reserved constructs emit explicit diagnostics. _Rationale:_ syntax without meaning is not completion. _Rejected:_ broad parser-only acceptance.

## Variants

- A green-tree parser may replace internals if incremental LSP performance requires it, preserving the public result and diagnostic contract.

## Referenced by

[[src/Pudu/Frontend/_MOC]] · [[Lexer]] · [[Token]] · [[Syntax]] · [[Compiler Pipeline]] · [[Frontend]] · [[Semantics]]
