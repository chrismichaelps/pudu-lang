---
type: handoff
status: REVIEW
issue: 196
tags: [handoff, http, tls, runtime, production-readiness]
---

# Public HTTP Integration and Deadlines

## Objective

Prove `Std.Http.Client.fetch` against public HTTP, HTTPS, and JSON endpoints, retain the discovered
transfer-framing and bounded-read regressions locally, and give each request chain one deadline that
covers resolution, connection, TLS verification, sending, reading, and redirects.

## Role Transitions

1. **Language Architect:** specify one monotonic whole-chain budget, zero/negative behavior, typed
   expiry, compatibility of existing builtins, and invalidation after interrupted stream operations.
2. **Runtime/Stdlib Implementer:** own the HTTP client, Net/TLS timeout variants, runtime adapters,
   deterministic fixtures, and public integration workflow; preserve unrelated UI work.
3. **Independent Reviewer:** inspect correctness and compatibility without editing and classify
   findings P0–P3.
4. **Forensic Guardian:** audit mirror fidelity, backlinks, changelog, private boundaries, source
   size, and delivery evidence.

## Review Resolution

Fresh-context review found that changing existing effect arities broke source compatibility, an
unbounded TLS goodbye could outlive the deadline, and interrupted send/receive operations left a
stream reusable after its state became unknowable. The implementation retains the original effects,
adds separately named `Within` effects, invalidates a connection when a timed stream operation
expires, and bounds TLS cleanup. Negative HTTP deadlines normalize to zero; low-level negative
operation timeouts remain the explicit unbounded compatibility form.

## Validation

- Controlled HTTP fixture covers decoded chunking, bounded response memory, a slow response, and a
  redirect chain that must share one deadline.
- Controlled TLS fixture covers a peer that accepts TCP and never completes the handshake.
- Zero-budget plain TCP send coverage proves interrupted writes invalidate their connection; the
  public TLS gate proves the corresponding secured send/read invalidation against a verified peer,
  because a deterministic local fixture has no certificate trusted by the system store.
- The scheduled/manual public fixture fetches example.com over HTTP and HTTPS, decodes the
  documented JSONPlaceholder todo over HTTPS, and asserts typed field values independent of JSON
  whitespace.
- The full 309-group suite, formatter, diagnostic registry, workflow YAML parse, and optimized
  warning-as-error build are required after review fixes.

## Exact Next Action

Split the issue into reviewable delivery partitions before PR promotion; the combined recovered
public-integration and deadline slice exceeds the mandatory 600-line review gate. The runtime module
size gate is resolved by [[Eval Builtin Definition]], which returns `Eval.Value` below 500 lines
without changing its public import surface.

## Referenced by

[[handoffs/_MOC]] · [[Std Http Client]] · [[Std Net]] · [[Std Tls]] · [[Engineering Delivery]]
