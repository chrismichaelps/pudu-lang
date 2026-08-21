---
type: changelog
tags: [changelog]
---

# Changelog

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
