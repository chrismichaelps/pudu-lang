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
data LexResult = LexResult { lexTokens :: ![Token], lexDiagnostics :: ![Diagnostic] }
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

Tail-recurse over the strict cursor in fixed precedence, recover one unmatched scalar with E0099, and complete once at EOF. Unexpected invariant failure becomes exact whole-source invalid output plus one EOF, never an exception.

## Negative Logic

- No parsing, source decoding, backtracking, token filtering, rendering, eager literal conversion, exception, or mutable state. Empty input is one EOF; trailing trivia attaches to EOF; scanner E0002–E0008 diagnostics pass through unchanged.

## Depth

DEPTH 0.61 (MEDIUM). Owns scanner precedence, total progress, unknown recovery, exact completion, and the public result boundary.

## Grill Log

- **Q:** Return `Maybe LexResult` because cursor operations validate invariants? **A:** No; expose a total phase result and preserve a conservative lossless fallback for impossible internal failure. _Rationale:_ user input cannot become a host-control-flow failure. _Rejected:_ `error`; empty-token fallback; leaking cursor internals.
- **Q:** Let the parser call scanners directly? **A:** No; parser/compiler imports the facade. _Rationale:_ one precedence and recovery contract prevents divergent token streams. _Rejected:_ caller-selected scanner order.
- **Q:** Batch unknown characters? **A:** No; recover one scalar per E0099. _Rationale:_ later valid tokens remain reachable and each defect has an exact actionable span. _Rejected:_ consume-to-whitespace recovery.

## Referenced by

[[src/Pudu/Frontend/_MOC]] · [[Frontend]]
