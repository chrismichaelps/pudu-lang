---
date: 2026-08-21
topic: frontend-foundation
from_role: DNA Engineer
to_role: Shadow
status: IMPLEMENT
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
- Authored issue #2 module page and implementation for [[Source]], including development/optimized property tests and GHC 9.14.1 CI.
- Merged issue #2 through PR #10 after independent Forensic Guardian review; source identity and span operations are now the validated dependency for diagnostics.
- Resolved the complete mirrored contract and Grill Log for issue #9's [[Diagnostic Model]].
- Implemented issue #9's opaque diagnostic model with normalized primary messages, ordered causality, complete render-key ordering, and severity-only error gating.
- Added a separate diagnostic test module with construction, decorator, permutation, and error-gate properties; development and optimized suites pass.
- Merged issue #9 through PR #11 after independent Language Architect and Forensic Guardian reviews.
- [Role: Forensic Guardian → Architect] Split the oversized token/cursor slice into issues #5 and #12; issue #6 now depends on the cursor.
- [Role: Architect → DNA Engineer] Resolved [[Token]] as a closed keyword/symbol vocabulary with exact mappings and lossless lexeme/trivia fields.
- [Role: DNA Engineer → Shadow] Committed the complete [[Token]] mirror and Grill Log before implementation.

## Decided (do not re-litigate)

- Hand-written strict lexer; hand-written recursive descent parser with precedence climbing.
- Unicode scalar offsets for the first source model, half-open spans, one-based display positions.
- Tokens preserve exact lexemes and leading trivia; invalid input stays in the stream.
- Recovery AST is never exposed as a compilable module when errors exist.
- First parser slice covers module/import/binding/function/block/literal/name/unary/binary/call/member/return/if constructs.

## Open / Remaining

- Issue #5: implement and validate only [[Token]]; issue #12 owns strict cursor state.
- Issues #12, #6, #7, and #8 complete the dependency-ordered lexer chain.
- Issue #3: commit complete mirrored module pages with resolved Grill Logs, then implement the modular syntax/parser/compiler slice.
- Run locked GHC 9.14.1 release gates and reconcile contract changes into pages first.

## Exact next action

Shadow: implement `@root/src/Pudu/Frontend/Token.hs` exactly from [[Token]], add a separate Token property suite, and exclude cursor/scanner/parser files from the branch.

## Links

[[grammar/haskell]] · [[grammar/pudu]] · [[architecture/SEMANTICS]] · [[Frontend]] · [[Token]] · [[Engineering Delivery]]

## Referenced by

[[handoffs/_MOC]] · [[FMCF Workflow]]
