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
sub-agents. The Linux CI repair of the host corpus was made in the Test
Engineer role and owned only `test/Pudu/Backend/HostPrograms.hs`, its mirror
page, the ledger, the changelog and this page: no runtime, grammar or
semantic file changed.

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

A third was in the corpus itself. The host program cut the refusal for
removing a directory through `removeFile` before the temporary root left the
text, so the cut landed inside the machine's own path: the recorded
expectation carried the author's own macOS temporary directory, and the
property failed on any machine whose temporary path was a different length.
The root now leaves the text first, and the window stops at the operation
name, because the system's own reason is a permission on one operating system
and an inappropriate type on another. The expectation is the same on every
machine, and the focused groups pass under a short temporary directory and a
long one alike.

A fourth was in the math kernels. glibc's `cbrt(27.0)` is one bit above
three; the interpreter calls the library and printed `3.0000000000000004`,
while the C compiler worked the native call out itself and printed `3.0`.
The library-accuracy kernels now read their operands through volatile
storage ([[Native Host Math]]), the written expectation states that kernel
through a relation, and a new group prints the library kernels in full
against the interpreter alone.

The remaining host families followed in one pass, in the Backend Engineer
and Test Engineer roles: stream endpoints, child programs, compression, time
rendering and reading, stop requests and TLS ([[Native Host Sockets]],
[[Native Host Child Programs]], [[Native Host Compression]], [[Native Host
Time]], [[Native Host Time Reading]], [[Native Host Signals]], [[Native Host
TLS]]), their rows in [[Compiler Lower Kernel Host]], the library flags in
[[Backend Toolchain]], and [[Backend Service Programs]]. Each program in the
corpus prints the same bytes in both engines on this host. TLS was also run
by hand against public hosts: a verified connection, a request and its
answer, the ending, and refused expired, mismatched and self-signed
certificates behaved alike in both engines; only the library's reason inside
`HandshakeFailed (...)` differs, by design.

Not done: foreign functions and handles, `unsafe` raw access, desktop, audio
and raster kernels keep E6001; trait-qualified method values stay with #647;
callee-first order stays with #828; `parseTime` refuses a number of more than
fifteen digits; ledger rows stay Partial until independent review.

Architect → Backend Engineer → Test Engineer. The follow-up owns the time
reader and its mirror, changelog and this handoff. The time-reading regression
in [[Backend Service Programs]] requires warning-free emission and preserves the
exact refusal text. The time reader now delegates message construction to the
shared checked text concatenation path.

Exact next action: request the independent implementation and wiki-parity
review of #846.

## Referenced by

[[handoffs/_MOC]]
