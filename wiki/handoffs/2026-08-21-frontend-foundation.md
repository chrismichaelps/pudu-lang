---
date: 2026-08-21
topic: frontend-foundation
from_role: DNA Engineer
to_role: Shadow
status: IN_PROGRESS
maturity: EXPLORING
tags: [handoff]
---

# Handoff — Frontend Foundation

## Done

- Established [[grammar/haskell]], [[grammar/pudu]], and normative [[architecture/SEMANTICS]].
- Established the architectural contracts that issue #2 and issue #3 must refine into mirrored module pages before their implementation files enter history.
- Resolved source offset units, frontend phase boundaries, recovery direction, precedence, and public validity constraints at architecture level.
- Established [[Engineering Delivery]] and private-input boundary.
- Established [[Performance Constitution]] for strict phase data, measured low-level representations, and proof-preserving optimization.

## Decided (do not re-litigate)

- Hand-written strict lexer; hand-written recursive descent parser with precedence climbing.
- Unicode scalar offsets for the first source model, half-open spans, one-based display positions.
- Tokens preserve exact lexemes and leading trivia; invalid input stays in the stream.
- Recovery AST is never exposed as a compilable module when errors exist.
- First parser slice covers module/import/binding/function/block/literal/name/unary/binary/call/member/return/if constructs.

## Open / Remaining

- Issue #2: commit complete mirrored module pages with resolved Grill Logs, then implement the modular source/diagnostic/token/lexer slice.
- Issue #3: commit complete mirrored module pages with resolved Grill Logs, then implement the modular syntax/parser/compiler slice.
- Run locked GHC 9.14.1 release gates and reconcile contract changes into pages first.

## Exact next action

DNA Engineer: on issue #2, reconcile and commit the Source/Diagnostic/Token/Lexer module pages before staging any Haskell, then implement from those versioned contracts with a thin lexer façade and separately owned scanner internals. The issue #1 governance PR must merge first.

## Links

[[grammar/haskell]] · [[grammar/pudu]] · [[architecture/SEMANTICS]] · [[Frontend]] · [[Engineering Delivery]]

## Referenced by

[[handoffs/_MOC]] · [[FMCF Workflow]]
