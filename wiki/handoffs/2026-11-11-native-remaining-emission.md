---
type: handoff
status: ACTIVE
issue: 846
aliases: [Native Remaining Emission Delivery]
---
# Native Remaining Emission Delivery

Architect → Backend Engineer → Test Engineer → Forensic Guardian self-audit.
feature/846-native-remaining-emission starts at dev 5c4c369c. Owned: Lower
Body, FunctionBody (new), Call, Generic, Method, Match, Types, State, Array,
Record, Sum, Lambda, Signature, Try, Constant, Intrinsic, Primitive, Kernel
and the new Concurrent, Scope, Dynamic and Kernel Host, Lanes and Shape; Core Kernel;
Emit Aggregate, Frame and Kernel; Runtime, Runtime Frame and the new Host
families; Toolchain; the checker's type-application fact and its key in
Source; HostPrograms and AbstractionPrograms (new) and the native spec and
leak registries; mirror pages, ledger, changelog and this page. No
sub-agents.

Resolved scope: [[Native Host Services]] and [[Native Type Abstractions]].

Evidence: every new program matches the interpreter byte for byte and
releases every allocation; the derive, default-self, dynamic and higher-kind
fixtures build natively and match. The full suite passed on the final tree in
eight shards (807 properties, all `OK`, every shard RC 0), `git diff --check`
is clean, and `node scripts/native-progress.mjs --check` passes. The entry and
named-function boundary lives in [[Compiler Lower Function Body]] (147 lines),
leaving [[Compiler Lower Body]] at 494 lines; written type-argument admission
moved to [[Compiler Lower Generic]]. Focused and full gate results are in the
pull request.

CI on Linux caught two boundary defects the macOS suite could not: the
emitted prelude redefined `_DEFAULT_SOURCE`/`_POSIX_C_SOURCE` inside the leak
harness's own translation unit, and `E7013` was not registered as one shared
meaning between the interpreter and native lowering. The prelude now defines
each macro only when absent; the diagnostic registry names the shared
condition. Focused leak groups and `node test/diagnostic-codes.mjs` pass.

Not done: foreign functions and handles, `unsafe` raw access, sockets and
TLS, child processes, compression, time formatting, signals, desktop, audio
and raster kernels keep E6001; callee-first order stays with #828; ledger
rows stay Partial until independent review.

Exact next action: request the independent implementation and wiki-parity
review of #846.

## Referenced by

[[handoffs/_MOC]]
