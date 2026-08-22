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
- [Role: Shadow → Forensic Guardian] Implemented [[Parser Binding]] with `E1012`/`E1013` name-class validation, optional type annotations, mandatory initializers, single-`E1001` unadmitted-keyword recovery, and focused success, failure, regression, diagnostic, and hostile-budget properties; development and `-O2` suites pass 83x200.

- [Role: Architect → Shadow] Resolved the newline statement boundary: a line break ends a statement unless the previous line ends with a binary operator or the next line begins with `.`, `?`, or `.await`; line-initial `(`/`[` never continue an expression.
- [Role: Shadow → Forensic Guardian] Implemented [[Parser Block]] with statement ordering, trailing-expression results, bare and valued `return`, trivia-derived line significance in [[Parser Expression]], latched `E1099` exhaustion in [[Parser State]], and focused boundary, continuation, nesting, recovery, and hostile-input properties; development and `-O2` suites pass 90x200.

- [Role: Shadow → Forensic Guardian] Implemented [[Parser Function]] with async/value-name signatures, parameters carrying optional types and defaults, optional `->` return types, block and expression bodies, `E1032` missing-body and `E1033` reserved-generic recovery, and focused signature, parameter, body, recovery, and hostile-input properties; development and `-O2` suites pass 96x200.

- [Role: Architect → Shadow] Resolved [[Parser Declaration]] as composition only: `export` ownership, preserved-but-diagnosed misplaced imports, reserved-declaration skipping over braced bodies, and consumed stray module-scope tokens.
- [Role: Shadow → Forensic Guardian] Implemented the orchestrator, the [[Parser]] façade over the source-bound state, and [[Compiler Pipeline]]'s source-to-module gate; a 21-line module with fluent chains, continued operators, default arguments, `if`/`return`, and an expression-bodied function parses with zero diagnostics. Development and `-O2` suites pass 103x200.

- [Role: Architect → Shadow] Resolved the remaining v1 surface grammar in [[grammar/pudu]]: pattern vocabulary, `case`-introduced match arms, `while`/`loop`/`for` expressions, `break`/`continue` statements, record/sum/alias `type` definitions, trait members with optional defaults, `impl` blocks, generic parameters with bounds, and `where` clauses.
- [Role: Shadow → Forensic Guardian] Extended [[Syntax Tree]] and [[Token]] for the full surface, then implemented [[Parser Pattern]], [[Parser Generic]], [[Parser Type Declaration]], [[Parser Trait]], the control and postfix expression forms, and loop statements. `E1033` and `E1043` are retired as features rather than reserved diagnostics; `E1050`, `E1051`, and `E1052` cover pattern, empty-match, and non-function-member recovery. Development and `-O2` suites pass 120x200.

- [Role: Architect → Shadow] Opened the semantic phase: resolution is two-pass at module scope, namespaces are separate, block bindings take effect after their initializer, variants stay in their type's namespace, and imports become opaque external symbols until a module graph exists.
- [Role: Shadow → Forensic Guardian] Implemented [[Symbol Model]], [[Scope Model]], [[Semantic Prelude]], and [[Name Resolution]], and extended [[Compiler Pipeline]] with `runCompile`. Prelude handling follows Haskell's split: wired-in types the compiler owns, an implicitly imported `Core.Prelude` module that an explicit import suppresses. Development and `-O2` suites pass 133x200.

- [Role: Architect → Shadow] Opened the execution and tooling slice: an evaluator so the language can be run before a backend exists, a source-quoting diagnostic renderer, and `puduci`, the interactive session.
- [Role: Shadow → Forensic Guardian] Implemented [[Diagnostic Render]], [[Evaluator]] with its four submodules, [[Pudu REPL]] with [[Repl Session]], [[Repl Command]], and [[Repl Outline]], and the [[Pudu CLI]]. Writing the evaluator's tests exposed three real defects — `return` and `break` were swallowed by nested blocks, and tuple expressions were missing from the grammar entirely — all three fixed here. Development and `-O2` suites pass 152x200.

- [Role: Shadow → Forensic Guardian] Added line editing, persistent history, Ctrl-C line cancellation, and Tab completion to `puduci` through [[Repl Complete]]. Completion covers colon commands, filenames after `:load`, the keyword vocabulary, wired-in and prelude names, and whatever the session declared or bound. Verified in a real terminal over a pseudo-terminal as well as by the pure completion properties; development and `-O2` suites pass 153x200.

- [Role: Shadow → Forensic Guardian] Audited the whole surface language through `puduci` and closed the last construction gap: records could be declared and matched but not built. Record construction expressions with field shorthand now parse, resolve, and evaluate; they are withheld in the expression before a block so `if READY { ... }` stays a block, and parentheses reinstate them. Character rendering now escapes control characters. Development and `-O2` suites pass 154x200, both warning-clean.

- [Role: Architect → Shadow] Opened the typing phase: local bidirectional inference only, declared generics rigid inside their declaration and instantiated per use, exported signatures annotated rather than inferred, and an absorbing error type so one mistake reports once.
- [Role: Shadow → Forensic Guardian] Implemented [[Type Value]], [[Type Env]], [[Type Formation]], [[Type Unify]], [[Type Check Rule]], [[Type Check Pattern]], [[Type Check]], and the [[Type Boundary]], and wired typing into [[Compiler Pipeline]] and `puduci`'s `:type`. Typing immediately moved two defects earlier: `1 + true` is now a type error rather than a runtime one, and a resolution test's program turned out to be ill-typed. Development and `-O2` suites pass 165x200, both warning-clean.

- [Role: Shadow → Forensic Guardian] Closed three gaps the typed REPL exposed: the wired-in `Option` and `Result` had no constructors, generic sums did not instantiate in patterns, and traits had no dispatch. `Some`/`None`/`Ok`/`Err` now exist in resolution, typing, and evaluation; `?` unwraps a `Result` and propagates its failure; and `value.method()` finds an implementation's method, inherits trait defaults, and reads `Self` as the implementing type. Development and `-O2` suites pass 168x200, warning-clean.

- [Role: Shadow → Forensic Guardian] Implemented [[Type Exhaust]]: a match over a closed sum or `Bool` must cover every constructor, an open domain needs an irrefutable arm, a guarded arm never counts toward coverage, and an arm after an irrefutable one warns. The check moved another defect earlier — an unmatched value that used to fail at run time is now refused at compile time. Development and `-O2` suites pass 169x200, warning-clean.

## Decided (do not re-litigate)

- Hand-written strict lexer; hand-written recursive descent parser with precedence climbing.
- Unicode scalar offsets for the first source model, half-open spans, one-based display positions.
- Tokens preserve exact lexemes and leading trivia; invalid input stays in the stream.
- Recovery AST is never exposed as a compilable module when errors exist.
- First parser slice covers module/import/binding/function/block/literal/name/unary/binary/call/member/return/if constructs.
- The interactive session is named `puduci` and prompts with `puduci> `. Its completion names come from a snapshot refreshed after each accepted entry, never from compiling inside a keystroke. Session state is pure and lives outside the IO loop, so a rejected entry leaves nothing behind.
- Evaluation exists before typing and before a backend. Its arithmetic is exact rather than width-dependent, and it says so; typing refines it rather than contradicting it.
- Wired-in types and the implicit prelude are separate scope layers, following Haskell: primitives cannot be removed, prelude names can be shadowed or replaced by an explicit `import Core.Prelude`.
- A record construction is withheld where a block may follow and reinstated by parentheses; ambiguity is resolved by position, never by lookahead.
- Statements are delimited by line breaks and braces. Continuation is decided from the operator token's own leading trivia; no terminator token is ever synthesized and no semicolon enters the grammar.

## Open / Remaining

- Issue #3: resolve and implement the declaration-orchestration partition — `export` ownership, module declaration, import ordering, declaration synchronization, and the compilation unit — which closes the issue; the untracked local drafts of `Parser.hs`, `Declaration.hs`, and `Compiler.hs` predate the current [[Parser State]] `runParser` signature and are not admitted history.
- Run locked GHC 9.14.1 release gates and reconcile contract changes into pages first.

## Exact next action

Forensic Guardian: review the completed surface, semantic, typing, execution, and tooling slices for wiki parity — [[Parser Binding]], [[Parser Block]], [[Parser Function]], [[Parser Declaration]], [[Parser]], [[Parser State]], [[Parser Expression]], [[Parser Pattern]], [[Parser Generic]], [[Parser Type Declaration]], [[Parser Trait]], [[Syntax Tree]], [[Token]], [[Name Resolution]], [[Evaluator]], [[Diagnostic Render]], [[Pudu REPL]], [[Type Check]], and [[grammar/pudu]] — against the commits on `dev`, then open the trait slice: bounds, coherence, and method dispatch over the typed tree.

## Links

[[grammar/haskell]] · [[grammar/pudu]] · [[architecture/SEMANTICS]] · [[Frontend]] · [[Token]] · [[Lexer Facade]] · [[Syntax]] · [[Syntax Located]] · [[Syntax Name]] · [[Syntax Tree]] · [[Parser Type]] · [[Parser Expression]] · [[Parser Import]] · [[Parser Binding]] · [[Engineering Delivery]]

## Referenced by

[[handoffs/_MOC]] · [[FMCF Workflow]]
