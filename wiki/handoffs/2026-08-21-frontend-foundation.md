---
date: 2026-08-21
topic: frontend-foundation
from_role: Architect
to_role: DNA Engineer
status: DESIGN
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
- [Role: Shadow → Forensic Guardian] Implemented [[Token]] with exhaustive keyword/symbol mappings and a separate losslessness/property suite.
- [Role: Forensic Guardian → Architect] Merged issue #5 through PR #13 after exact grammar, losslessness, locked-CI, Language Architect, and Forensic Guardian gates passed.
- [Role: Architect → DNA Engineer] Promoted issue #12 to Ready and constrained its cursor to strict suffix traversal, opaque snapshot marks, and one completion path.
- [Role: DNA Engineer → Shadow] Resolved [[Lexer Cursor]] with committed-point segment ownership so scanners cannot skip, overlap, or duplicate source.
- [Role: Shadow → Forensic Guardian] Implemented the strict cursor and focused properties for scalar traversal, snapshot capture, segment ownership, losslessness, diagnostics, and EOF completion.
- [Role: Forensic Guardian → Architect] Merged issue #12 through PR #14 after frontend, forensic, development, optimized, and locked-CI gates passed.
- [Role: Architect → DNA Engineer] Resolved issue #6 as separate [[Trivia Scanner]] and [[Identifier Scanner]] modules plus one measured cursor prefix primitive.
- [Role: DNA Engineer → Shadow] Committed complete scanner mirrors and Grill Logs before implementation.
- [Role: Shadow → Forensic Guardian] Implemented both scanners, the maximal-prefix cursor primitive, exact E0003 recovery, and focused Unicode/nesting/losslessness properties.
- [Role: Forensic Guardian → Architect] Merged issue #6 through PR #15 after exact-head scanner, forensic, optimized, and locked-CI gates passed.
- [Role: Architect → DNA Engineer] Resolved issue #7 numeric ownership, range ambiguity, E0004 recovery, and closed longest-match symbols.
- [Role: DNA Engineer → Shadow] Committed complete [[Number Scanner]] and [[Symbol Scanner]] mirrors before implementation.
- [Role: Shadow → Forensic Guardian] Implemented textual number validation, exact E0004 recovery, longest-match symbols, ambiguity/stress properties, and optimized gates.
- [Role: Forensic Guardian → Architect] Merged issue #7 through PR #16 after exact-head semantic, forensic, optimized, and locked-CI gates passed.
- [Role: Architect → DNA Engineer] Split issue #8 into bounded quoted-scanner and facade integrations; resolved [[Quoted Scanner]] delimiter ownership, scalar-safe escape decoding, and E0002/E0005–E0008 recovery.
- [Role: DNA Engineer → Shadow] Committed the complete [[Quoted Scanner]] mirror and Grill Log before implementation.
- [Role: Shadow → Forensic Guardian] Implemented quoted decoding and focused success, failure, recovery, losslessness, and long-literal properties; PR #17 review required completing the same issue with its bounded facade.
- [Role: Forensic Guardian → Architect] Kept issue #8 atomic, resolved [[Lexer Facade]], and constrained the combined PR below 600 changed lines rather than closing a partial issue.
- [Role: Architect → DNA Engineer] Committed the complete facade mirror and Grill Log before its implementation.
- [Role: DNA Engineer → Shadow] Re-anchored implementation to the facade mirror and assigned only facade, focused integration tests, and package exposure.
- [Role: Shadow → Forensic Guardian] Implemented the total facade, fixed scanner precedence, exact E0099 recovery, conservative lossless invariant fallback, generated losslessness properties, and development/optimized gates.
- [Role: Forensic Guardian → Architect] Merged issue #8 through PR #17 after exact-head semantic, forensic, size, optimized, and locked-CI gates passed.
- [Role: Architect → DNA Engineer] Selected issue #3's dependency-first syntax slice and resolved the complete [[Syntax]], [[Syntax Located]], [[Syntax Name]], and [[Syntax Tree]] mirrors before history admission.
- [Role: DNA Engineer → Shadow] Committed the four syntax mirrors and maps before staging their implementation files.
- [Role: Shadow → Forensic Guardian] Admitted the modular syntax data and direct provenance/name/recovery invariants with package exposure.
- [Role: Forensic Guardian → Architect] Clarified delivery so issue #3 can use honest sub-600 intermediate `Refs` partitions without opening artificial issues; only its final partition closes the issue.
- [Role: Forensic Guardian → Architect] Merged issue #3 syntax partition through PR #18 after exact-head semantic, forensic, optimized, and locked-CI gates passed.
- [Role: Architect → DNA Engineer] Resolved parser state/name source ownership, source-end EOF normalization, opaque diagnostic construction, closed symbol mapping, declaration boundaries, and segmented-name casing before implementation admission.
- [Role: DNA Engineer → Shadow] Committed [[Parser State]], [[Parser Name]], and their active parser map before staging source.
- [Role: Shadow → Forensic Guardian] Repaired the preserved state/name implementations against opaque diagnostics and closed symbols; added EOF, progress, budget, casing, and trailing-dot properties.
- [Role: Forensic Guardian → Architect] Merged the state/name partition through PR #19 after canonical EOF, linear cursor, bounded path, semantic, forensic, optimized, and locked-CI gates passed.
- [Role: Architect → DNA Engineer] Resolved [[Parser Type]] ownership, closed punctuation, E1020 recovery, delimiter behavior, and shared recursion budgeting before implementation admission.
- [Role: DNA Engineer → Shadow] Committed the complete [[Parser Type]] mirror and maps before staging source.
- [Role: Shadow → Forensic Guardian] Implemented bounded reference, tuple/unit, named, and generic parsing with focused success, recovery, and hostile-nesting properties.
- [Role: Forensic Guardian → Architect] Merged the type partition through PR #20 after grammar reconciliation, recovery/budget, semantic, forensic, optimized, and locked-CI gates passed.
- [Role: Architect → DNA Engineer] Resolved [[Parser Expression]] associativity, closed operator ownership, block capability injection, recovery diagnostics, and hostile-chain budgeting before implementation admission.
- [Role: DNA Engineer → Shadow] Committed the complete [[Parser Expression]] mirror, normative associativity, maps, and backlinks before staging source.
- [Role: Shadow → Forensic Guardian] Implemented closed-vocabulary precedence climbing, unary/postfix/conditional parsing, explicit reserved-postfix recovery, and hostile-chain properties.
- [Role: Forensic Guardian → Architect] Merged the expression partition through PR #21 after cascade-free budget recovery, exact hostile spans, semantic, forensic, optimized, and locked-CI gates passed.
- [Role: Architect → DNA Engineer] Split declaration grammar into modular import/binding/function/block/orchestration files and resolved [[Parser Import]] alias/selection exclusivity, trailing commas, diagnostics, progress, and budgets first.
- [Role: DNA Engineer → Shadow] Committed the complete [[Parser Import]] mirror, declaration map, grammar clarification, and backlinks before staging source.
- [Role: Shadow → Forensic Guardian] Implemented modular import parsing, reusable uppercase aliases, cascade-free shared budgets, and focused success, failure, regression, diagnostic, and hostile-input properties.
- [Role: Forensic Guardian → Architect] Validated the modular import partition through PR #22 with exact-head Language Architect, forensic, development, optimized, package, size, private-boundary, and locked-CI gates passing.
- [Role: Architect → DNA Engineer] Resolved [[Parser Binding]] as separate top-constant/local-binding entry points with explicit name classes, injected block capability, recovery boundaries, and no module `let`/`var` admission.

## Decided (do not re-litigate)

- Hand-written strict lexer; hand-written recursive descent parser with precedence climbing.
- Unicode scalar offsets for the first source model, half-open spans, one-based display positions.
- Tokens preserve exact lexemes and leading trivia; invalid input stays in the stream.
- Recovery AST is never exposed as a compilable module when errors exist.
- First parser slice covers module/import/binding/function/block/literal/name/unary/binary/call/member/return/if constructs.

## Open / Remaining

- Issue #3: commit and implement the modular binding declaration partition before function/block/orchestration behavior.
- Run locked GHC 9.14.1 release gates and reconcile contract changes into pages first.

## Exact next action

DNA Engineer: commit [[Parser Binding]], name-class governance, maps, changelog, and backlinks before staging source.

## Links

[[grammar/haskell]] · [[grammar/pudu]] · [[architecture/SEMANTICS]] · [[Frontend]] · [[Token]] · [[Lexer Facade]] · [[Syntax]] · [[Syntax Located]] · [[Syntax Name]] · [[Syntax Tree]] · [[Parser Type]] · [[Parser Expression]] · [[Parser Import]] · [[Parser Binding]] · [[Engineering Delivery]]

## Referenced by

[[handoffs/_MOC]] · [[FMCF Workflow]]
