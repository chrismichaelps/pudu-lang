---
type: handoff
tags: [handoff, performance, compiler]
---

# Compiler checking latency

Issue #435 starts from freshly fetched dev (71fb2adf) in
`feature/435-compiler-latency`, isolated from the active Derive checkout.
Architect → Tooling/Performance Engineer owns the whole-compiler benchmark and
its measured hotspot. Work is solo. Preserve canonical graph visibility,
semantics, diagnostic products and cache validity. No PR or dev promotion yet.

The dependency layers are process/RTS startup → source discovery → frontend →
shared graph interfaces → per-module expansion/resolution/checking → constants
→ persistent products → CLI reporting. Measure before changing each layer.
Haskell bootstrap build time and interpreted program time are distinct outputs;
a reduced CI build cannot claim a faster Pudu type checker.

Baseline on the Derive checkpoint binary, GHC 9.10.3, optimized, cache disabled:
25/50/100/200 sparse modules take 53/77/136/216 milliseconds and allocate
34/67/134/272 MB. A valid graph importing all 214 Std modules with unique aliases
takes 1,179 ms and allocates 1.919 GB. A valid seven-library composition takes
202 ms. Scratch failures from incorrect imports/alias collisions are excluded.
Reproduce on the dev binary before attributing a fix to this issue.

Resolved Grill Log: profile the slow layer and preserve its observable products;
failed checks are harness failures, never successful fast samples. Use fresh
cache directories and explicit cold/warm cases. Record actual wall time and RTS
CPU/allocation/residency, without subtracting startup from displayed latency.
The benchmark is a standalone measurement tool, not a wall-clock unit test.

## Exact next action

Attribute the remaining checker allocation to state copying and live recorded
facts on the unchanged 8,000-branch workload before changing its representation.

## Referenced by

[[handoffs/_MOC]] · [[Performance Constitution]] · [[Compiler Program]]

Architect → Semantic/Performance Engineer owns Type.Env, Type.Frontier and its
spec, test registration, benchmark and mirrors. Profiling places type checking
in the dominant layer. A valid branch-heavy body at 1,000/2,000/4,000/8,000
statements allocates 318 MB/1.15 GB/4.35 GB/16.90 GB and checks in approximately
94/292/1,033/4,208 ms. The creation-frontier selectors partition every pending
literal rather than the recent interval; exploit their existing decreasing order.
No scheduler policy change is justified: the compiler-only probe did not improve
with fewer capabilities. Preserve runtime concurrency and explicit flag handling.

The frontier checkpoint passes the optimized warning-as-error build and all 464
property families on GHC 9.10.3. The diagnostic inventory reports 154 codes,
33 shared groups and 243 sources. The harness refuses malformed arguments and
missing RTS statistics. Local toolchain evidence does not claim the locked CI
GHC 9.14.1 has run.

Three cache-disabled samples with matching dev library and ordinary optimized
binaries measure 8,000 branches at a minimum 4,105.4 ms before and 287.3 ms after;
allocation falls from 16,902,136,984 to 524,985,232 bytes. At 4,000 branches it
falls from 1,032.8 to 151.6 ms. Negative literal bodies fall from 326.4 to 83.7 ms.
All 213 Std modules remain about 1,115 ms and 1.80 GB allocation. Do not attribute
unaffected layers or warmed product reuse to the frontier fix.

The 525 MB is cumulative allocation. RTS reports about 47 MB maximum live heap
and 152 MiB heap memory in use. A separate macOS wait4 measurement gives about
170 MB process peak RSS. On an equivalent 8,000-conditional C checking workload,
Clang 21.1.8 measures 31 ms and about 30 MB RSS after the first run (first run
298 ms). The languages and compiler products differ; this comparison establishes
a target, not language-feature or native-code parity.

Forced-GC phase attribution measures roughly 122 MB lexing, 84 MB parsing,
27 MB expansion, 30 MB resolution, 172 MB type checking and 89 MB type-product
publication. Expression map construction accounts for 87.5 MB of the final
phase. Sorted bulk construction saves only 21 MB and was slower in the probe;
do not adopt it merely because fewer bytes were measured. Diagnostic-only
callers should avoid building this unused map while tooling retains its answers.

Frontier checkpoint committed as 16d80cb8. Architect → Semantic Engineer now
owns Type.hs and its mirror only for derived expression-map demand. Resolved
Grill Log: defer the published lookup index, preserve the complete checker walk,
literal products and diagnostic admission, and exercise existing editor/doc
consumers before accepting the allocation measurement.

Demand-driven TypeInfo saves 87.5 MB allocation (525 MB → 437 MB) and measures
250 ms after the first run, but peak RSS remains around 194 MB under the default
eight-capability RTS. Do not confuse this mode with the earlier two-capability
RSS sample. Extend Semantic ownership to Type.Env's private substitution
representation: benchmark strict integer-keyed storage against the same binary
configuration before retaining it. No public type or checker semantics change.

Integer-keyed substitutions reduce the same check to 413,778,832 allocated bytes
and a minimum 238 ms in three samples; peak RSS remains about 194 MB. All 464
families, optimized -Werror build and live language-server session pass. The
complete compiler corpus verifies cold/first-cache/warm diagnostics and products:
4,000 branches take 129 ms; 4,000 negative literals 72 ms; 200 graph modules
157 ms; all 213 Std modules remain 1,106 ms. The last workload retains about
228 MB live heap; allocation reduction alone has not repaired graph retention.

Cold compile results retain tokens, resolution, deferred type/doc indexes and
the pre-lowering tree even through an execution-only CLI call. Warm cache hits
already provide only executable products. Trace that publication boundary next;
the existing full-analysis API must continue serving tooling and REPL context.

Allocation checkpoint committed as 93a310d2. Architect → Tooling Engineer owns
Compiler.Program, new Compiler.Product, cache/publication specs and registration.
Resolved Grill Log: explicit analysis/execution publication, no skipped phases,
materialized rejected-frontend diagnostics before sequential checking, identical
cache keys and full context/source retention. Keep Program below 500 lines by
moving its existing per-module cache admission to the product boundary.

Initial compact publication reduces all-Std maximum live heap to roughly 128 MB
and process RSS to 346–358 MB in three cache-disabled samples. Investigate whether
integer-kind selector thunks retain the full typing result. Extend ownership to
Compiler.hs for a single shared kind binding, and force that required map only
at executable publication before accepting the final memory measurement.

The shared-kind forcing experiment did not materially improve allocation, RSS
or latency and is removed. Extend ownership to Frontend.Expand and its mirror
for unchanged-tree sharing. Resolved Grill Log: the existing complete walk must
still diagnose unknown/rejected macros; zero hygienic identities plus zero
findings proves that returning the original tree changes no syntax.

Compact publication and unchanged-tree sharing pass all 465 property families,
the optimized warning-as-error build, formatting, diagnostic inventory, live LSP,
documentation-site parity and all seven tree/compiled benchmark output checks.
In three cache-disabled samples, the 8,000-branch check allocates 409,891,648
bytes, retains about 41 MB live heap and peaks at 185–186 MB RSS. Wall samples
are 1,763/233/236 ms; preserve the first-run cost in the evidence. All-Std uses
1,665,950,888 bytes allocation, about 127 MB live heap and 345 MB RSS; samples
are 1,038/973/980 ms. The complete compiler corpus's all-Std cold median is
975 ms and warm median 87 ms. Native-compiler memory parity remains unmet.

The unchanged-tree guard is proven for this dev branch's macro-only expansion.
Before integrating into Derive, extend the change witness to every Derive
transformation: zero macro identities cannot prove that no methods were generated.

Product-lifetime checkpoint committed as 2477c5d3 and pushed to its feature
branch, together with CI checkpoint 92b0a144 on feature/436-ci-latency. Continue
Architect → Tooling/Performance Engineer ownership of Compiler.Product and
Compiler.Program for execution-only frontend release. Resolved Grill Log:
complete the canonical frontend and preserve all findings and source snapshots;
drop token/trivia lists before discovery retains a module, while analysis keeps
its tokens and bypasses token-free cache reuse. Benchmark identical workloads
before accepting the change; publication/graph/editor tests remain required.

Early frontend release measures about 158 MB RSS on 8,000 branches (232/240 ms
after the first run), and 314–317 MB on all Std modules (946–951 ms). Allocation
is unchanged, as expected: this repairs lifetime rather than the lexer walk.
Extend Architect → Semantic/Performance Engineer ownership to Type.Env's
producedTypes strictness and mirror. Resolved Grill Log: preserve the full live
checker record for collection/place checks and defer only the final tooling
list, whose downstream map is already demand-driven. Measure before retention.

Early frontend release plus demand-driven CheckerProducts pass all 465 property
families, optimized -Werror, formatter, diagnostic inventory, live LSP, doc-site
parity and the seven evaluator output checks. The original evaluator script
reports MultiMap 0.92 s tree / 0.95 s compiled. The compiler corpus verifies all
cold/first-cache/warm results; 4,000 branches have a 122 ms cold median, 200
graph modules 135 ms, and all 213 Std modules 974 ms (98 ms warm).

The unchanged 8,000-branch process allocates about 401.8 MB, retains roughly
33 MB live heap and peaks near 158 MB RSS. Deferring the final expression list
saves 8.1 MB allocation without materially changing peak RSS. The separate
all-Std measurement allocates 1.65 GB, retains roughly 103 MB and peaks at
316 MB RSS. Its wall samples are 979/944/946 ms. Branch samples are
2,847/266/284 ms; timing varied between passes and the first invocation remains
slow. Keep allocation, live heap, RSS and first-run latency distinct. The
C/C++ memory target remains open; no new capability or heap-growth policy was
introduced. Editor/type/diagnostic behavior remains covered in full analysis.
