---
type: module
path: "@root/src/Pudu/Frontend/Lexer.hs"
fidelity: Active
domain: "[[Source Text]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.61
depth_status: MEDIUM
tags: [module, medium, lexer]
aliases: [Lexer Facade]
---

# Lexer Facade

> `{-| @Source.Lexer.Module — exposes total lossless tokenization -}`

## Purpose

Drive modular scanners in one deterministic order and expose tokens plus ordered diagnostics for every decoded source snapshot.

## Interface

```haskell
data LexResult = LexResult
  { lexTokens :: ![Token]
  , lexDiagnostics :: ![Diagnostic]
  }

lexSource :: Source -> LexResult
```

## Governance

- Drain trivia first; at non-EOF positions try quoted, number, identifier, then longest-match symbol scanning. This keeps comments ahead of `/`, malformed numbers owned, and quoted recovery distinct from fallback.
- If no scanner matches, consume exactly one scalar, emit `Invalid` with identical text, and record E0099 `unrecognized input` over that scalar.
- Every loop step commits positive width; completion occurs once at EOF, diagnostics sort once, and final trivia belongs to the single zero-width EOF token.
- Concatenating every token's leading trivia and exact lexeme reconstructs `sourceText` exactly. Decoded literal payload never replaces its lexeme.
- The facade receives decoded `Source`; byte decoding and E0001 remain ingestion responsibilities. E0002 remains quoted-scanner unterminated recovery and is never rewritten as E0099.
- A conservative whole-source invalid result preserves totality and losslessness if an internal cursor invariant unexpectedly prevents completion; ordinary source behavior must never reach it.

## Algorithm

1. Tail-recurse over the strict cursor, selecting the first matching scanner in fixed precedence.
2. Recover an unmatched scalar through an exact invalid token and E0099.
3. At EOF, complete the cursor and copy its ordered output into `LexResult`.
4. If completion unexpectedly fails, return an exact whole-source invalid token, one EOF at source end, and E0099 rather than throwing or dropping source.

## Negative Logic

- No parsing, source decoding, scanner backtracking, token filtering, diagnostic rendering, eager literal conversion, exception, or hidden mutable state.

## Edge Cases

- Empty input is one EOF. Trailing trivia attaches to EOF.
- `/`, `//`, and `/*...*/` select symbol or trivia without ambiguity.
- `;`, a lone `\\`, a leading combining mark, and a non-ASCII digit each recover as one-scalar E0099 invalid tokens before later valid tokens.
- Scanner diagnostics E0002–E0008 pass through unchanged; quoted-invalid text never splits into E0099 tokens.

## Depth

DEPTH 0.61 (MEDIUM). The facade owns scanner precedence, total progress, unknown-input recovery, exact completion, and the public lexical result boundary.

## Grill Log

- **Q:** Return `Maybe LexResult` because cursor operations validate invariants? **A:** No; expose a total phase result and preserve a conservative lossless fallback for impossible internal failure. _Rationale:_ user input cannot become a host-control-flow failure. _Rejected:_ `error`; empty-token fallback; leaking cursor internals.
- **Q:** Let the parser call scanners directly? **A:** No; parser/compiler imports the facade. _Rationale:_ one precedence and recovery contract prevents divergent token streams. _Rejected:_ caller-selected scanner order.
- **Q:** Batch unknown characters? **A:** No; recover one scalar per E0099. _Rationale:_ later valid tokens remain reachable and each defect has an exact actionable span. _Rejected:_ consume-to-whitespace recovery.

## Referenced by

[[src/Pudu/Frontend/_MOC]] · [[Frontend]]
