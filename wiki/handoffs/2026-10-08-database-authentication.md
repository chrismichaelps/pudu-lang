---
type: handoff
status: REVIEW_PENDING
issue: 474
tags: [database, authentication]
aliases: [Database Authentication Delivery]
---
# Database Authentication Delivery

Language Architect resolved finite challenge admission before readiness. Runtime Engineer owns Std.Db.Challenge and Std.Db.Session. Test Engineer owns dbauth/Main, its Std.Net substitute, AuthenticationSpec and runner/manifest registrations. Tooling Engineer owns the new Challenge classification and the exact layer-diagnostic expectation in the graph regression. Complete owned mirrors with resolved Grill Logs precede source edits. Work is direct and sequential on feature/474-authentication-budget from fetched development c2b436a8. Preserve pushed import repairs and all unrelated work. Transitions: Language Architect → Runtime Engineer → Test Engineer → Tooling Engineer. Independent implementation, public-boundary and vault-parity review remains required.

The validator bounds both payloads to 8192 bytes and rounds to 1000000 before derivation. It validates phase identifiers, text, ordered required fields, duplicate/mandatory fields, canonical encodings and nonce contribution; optional well-formed extensions preserve exact proof text. Final proof comparison uses constantTimeEqual. Session checks its deadline around derivation without a computation-preemption guarantee. Existing Config and Auth shapes stay intact. Protected transport, outer authentication state ordering and resource retirement remain audit gaps.

Acceptance includes deterministic pure/refusal/exchange tests in both modes; no proof after first refusal, header-only oversized admission and closed failed sockets; proof vector, removal control, fresh strict optimized build, focused/full gates, direct/carried/source-only execution, library/API/format/lint/graphs and vault parity.

The fresh strict optimized build and focused family pass. Pure boundary checks, observed valid/refused exchanges and an independent proof vector run in both evaluators. The preliminary fixture expected the initial read-ahead request to subtract five bytes; actual retained framing permits the full 64 KiB request. Its expectation was corrected to [5, 65536, 5] after inspecting the exact requests. The inserted layer changes the existing upward-edge diagnostic from hosting layer nine to ten; the inspected expectation is aligned. All five layer regressions now pass.

Two direct runs and six packaged runs pass after deleting original sources, using an empty environment and unrelated working directory. Carried execution contains 24 products; a changed-digest source-only stand-in contains none. This is local execution evidence, not another-platform evidence. Restoring a malformed-round fallback in a temporary validator copy makes the regression refuse with E7007 as required. API coverage is 3633 of 3992 exports with no undocumented export; formatting, command lint, diagnostic consistency and added vault links pass.

All 604 complete-suite groups pass with zero failing groups, and all 244 shipped library/example sources check. Formatting, command lint, five graph regressions and the application graph pass: 216 modules and 97 dependencies, zero findings. The native source graph has 282 modules, 31 layers and no missing edges or cycles. New links and the private-input boundary pass the author audit; independent implementation, public-boundary and vault-parity reviews remain pending.

Local derivation measurement uses three samples per count, a 32-byte key, password pencil and salt salt; elapsed time surrounds deriveKey and the output-length check. Median times are 3 ms at 4096 rounds, 641 ms at 1000000 and 6257 ms at 10000000. The admission ceiling reduces maximum server-selected rounds tenfold; larger counts perform no derivation. These are local optimized measurements, not a portable latency guarantee. The first measurement invocation used a mismatched temporary module path and was corrected before measurement.

Exact next action: obtain independent implementation, public-boundary and vault-parity review of the draft #474 delivery before integration. The original application goal remains active.

## Referenced by

[[handoffs/_MOC]] · [[Std Db Session]] · [[Std Db Challenge]] · [[Database Challenge Spec]]
