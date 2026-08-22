---
type: changelog
tags: [changelog]
---

# Changelog

- 2026-08-21 · [[Parser Expression]], [[Syntax Tree]], [[Evaluator]], and [[grammar/pudu]] · admit record construction expressions with field shorthand, withheld before a block to keep `if Name { ... }` unambiguous · risk MED · depth DEEP→DEEP · issue #3
- 2026-08-21 · [[Pudu REPL]] and [[Repl Complete]] · add line editing, persistent history, Ctrl-C line cancellation, and Tab completion over commands, filenames, keywords, wired-in types, prelude names, and session bindings · risk MED · depth MEDIUM→MEDIUM · issue #3
- 2026-08-21 · [[Pudu REPL]], [[Repl Session]], [[Repl Command]], [[Repl Outline]], and [[Pudu CLI]] · establish the `puduci` interactive session with persistent context, multi-line entry, colon commands, file loading, and the `pudu` executable · risk MED · depth n/a→MEDIUM · issue #3
- 2026-08-21 · [[Evaluator]], [[Eval Value]], [[Eval Env]], [[Eval Match]], and [[Eval Operator]] · establish tree-walking evaluation with unwinding control flow, total pattern matching, bounded recursion and iteration, and `E7xxx` runtime diagnostics · risk HIGH · depth n/a→DEEP · issue #3
- 2026-08-21 · [[Diagnostic Render]] · establish source-quoting diagnostic rendering with carets, related notes, help, and an interactive line mapping · risk MED · depth n/a→MEDIUM · issue #3
- 2026-08-21 · [[Parser Expression]] and [[grammar/pudu]] · admit tuple expressions, closing the gap between tuple types and tuple patterns · risk MED · depth DEEP→DEEP · issue #3
- 2026-08-21 · [[Name Resolution]] · admit unqualified variant names while unambiguous and report `E2012` when two types share a spelling, matching the grammar's qualification rule · risk MED · depth DEEP→DEEP · issue #3
- 2026-08-21 · [[Name Resolution]], [[Symbol Model]], [[Scope Model]], and [[Semantic Prelude]] · establish two-pass lexical name resolution with namespaced symbols, Haskell-style wired-in and implicit-prelude scope layering, and `E2001`/`E2010`/`E2011`/`W2001` diagnostics · risk HIGH · depth n/a→DEEP · issue #3
- 2026-08-21 · [[Parser Trait]] and [[Parser Type Declaration]] · implement record, sum, and alias `type` declarations, trait contracts with optional default bodies, and `impl` blocks with `E1052` member recovery · risk MED · depth n/a→MEDIUM · issue #3
- 2026-08-21 · [[Parser Pattern]] and [[Parser Generic]] · implement the closed pattern vocabulary with alternation, ranges, and record rests, plus shared generic parameters, bounds, and `where` clauses · risk MED · depth n/a→MEDIUM · issue #3
- 2026-08-21 · [[Syntax Tree]] and [[Token]] · extend the surface data to patterns, match arms, loops, jumps, function types, generics, and the type/trait/impl declaration family, and admit `=>` into the closed symbol vocabulary · risk HIGH · depth MEDIUM→MEDIUM · issue #3
- 2026-08-21 · [[Parser Expression]] · admit `match`, `while`, `loop`, `for`, indexing, `?` propagation, and `.await`, replacing the reserved `E1043` postfix diagnostic · risk HIGH · depth DEEP→DEEP · issue #3
- 2026-08-21 · [[Parser Declaration]], [[Parser]], and [[Compiler Pipeline]] · complete the first frontend slice with compilation-unit orchestration, `export` ownership, `E1034`/`E1038`/`E1039` recovery, and source-to-module phase gating · risk HIGH · depth n/a→MEDIUM · issue #3
- 2026-08-21 · [[Parser Function]] · implement `async`/`fn` signatures, parameters with optional types and defaults, return types, block and expression bodies, and `E1032`/`E1033` recovery · risk MED · depth n/a→MEDIUM · issue #3
- 2026-08-21 · [[Parser Block]] · implement newline-delimited block statements, block results, `return` statements, line-sensitive expression continuation, and latched `E1099` recovery · risk HIGH · depth n/a→MEDIUM · issue #3
- 2026-08-21 · [[Parser Binding]] · implement module constants and local `let`/`var`/`const` bindings with `E1012`/`E1013` name classes, single-`E1001` unadmitted-keyword recovery, and injected initializer blocks · risk MED · depth n/a→MEDIUM · issue #3
- 2026-08-21 · [[Parser Binding]] · specify scope-safe module constants and local bindings with value/constant name classes and injected initializer blocks · risk MED · depth n/a→MEDIUM · issue #3
- 2026-08-21 · [[Parser Import]] · implement modular bounded absolute imports, exclusive alias/selection suffixes, trailing commas, and E1030/E1031 recovery · risk MED · depth n/a→MEDIUM · issue #3
- 2026-08-21 · [[Parser Expression]] · specify closed-vocabulary bounded precedence, postfix, conditional, E1040/E1042/E1043 recovery · risk HIGH · depth n/a→DEEP · issue #3
- 2026-08-21 · [[Parser Type]] · specify bounded reference, tuple/unit/grouped, named, generic, trailing-comma, and E1020 recovery syntax · risk MED · depth n/a→MEDIUM · issue #3
- 2026-08-21 · [[Parser State]] and [[Parser Name]] · establish source-bound EOF normalization, bounded suffix traversal, opaque diagnostics, and segmented paths · risk MED · depth n/a→DEEP/MEDIUM · issue #3
- 2026-08-21 · [[Syntax]] · establish located segmented recovery-capable untyped surface data · risk MED · depth n/a→MEDIUM · issue #3
- 2026-08-21 · [[Quoted Scanner]] and [[Lexer Facade]] · establish bounded quoted decoding, total lossless tokenization, E0002/E0005–E0008, and E0099 recovery · risk MED · depth n/a→MEDIUM · issue #8
- 2026-08-21 · [[Number Scanner]] and [[Symbol Scanner]] · establish textual numeric validation, E0004 recovery, and longest-match symbols · risk MED · depth n/a→MEDIUM · issue #7
- 2026-08-21 · [[Trivia Scanner]] and [[Identifier Scanner]] · establish modular Unicode trivia/name scanning and E0003 recovery · risk MED · depth n/a→MEDIUM · issue #6
- 2026-08-21 · [[Lexer Cursor]] · establish strict snapshot-safe traversal, committed segments, and deterministic completion · risk MED · depth n/a→DEEP · issue #12
- 2026-08-21 · [[Pudu Language]] · establish FMCF vault and resolve v1 architecture, semantics, and ownership foundation · risk HIGH · depth n/a→specified · [[ADR-0001-language-purpose-and-v1-scope]] · [[ADR-0002-compiler-pipeline]] · [[ADR-0003-ownership-and-resource-safety]]
- 2026-08-21 · [[Engineering Delivery]] · establish issue/branch/PR/agent-review/release construction · risk MED · depth n/a→specified · [[ADR-0004-team-delivery-and-agent-review]]
- 2026-08-21 · [[Performance Constitution]] · lock compiler-throughput and low-level generated-code optimization laws · risk HIGH · depth n/a→specified · [[ADR-0005-performance-and-low-level-optimization]]
- 2026-08-21 · [[architecture/SEMANTICS]] · clarify default evaluation, module constants, and structural `Copy` before implementation · risk HIGH · depth specified→reviewed · [[ADR-0003-ownership-and-resource-safety]]
- 2026-08-21 · [[architecture/SEMANTICS]] · define replacement/reinitialization and normalized sync/async failure signatures before implementation · risk HIGH · depth reviewed→grilled · [[ADR-0003-ownership-and-resource-safety]]
- 2026-08-21 · [[Source]] · establish opaque snapshot identity, cached Unicode-scalar bounds, overflow-safe offsets, and allocation-conscious positions · risk MED · depth n/a→MEDIUM · issue #2
- 2026-08-21 · [[Diagnostic Model]] · establish deterministic structured diagnostics, ordered causality, and severity-only error gating · risk MED · depth n/a→MEDIUM · issue #9
- 2026-08-21 · [[architecture/SEMANTICS]] · fix diagnostic-code shape and severity-family compatibility before phase publication · risk MED · depth grilled→clarified · issue #9
- 2026-08-21 · [[Token]] · establish closed keyword/symbol vocabulary and lossless token/trivia representation · risk MED · depth n/a→MEDIUM · issue #5

## Referenced by

[[00-INDEX]] · [[FMCF Workflow]]
