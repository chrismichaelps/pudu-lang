---
type: handoff
status: ACTIVE
issue: 842
aliases: [Native Builtin Kernel Delivery]
---
# Native Builtin Kernel Delivery

Architect → Backend Engineer → Test Engineer → Forensic Guardian self-audit.
feature/842-native-kernels starts at dev 7817138c, after PR #841 merged under
the standing C11 merge rule. Owned: Core kernel names; Lower Kernel, Swiss,
Primitive (new), Intrinsic, Body, Layout; Frame Body and Frame Value; Emit
Kernel (new) and Frame Value; runtime families under Runtime/Kernel (new) and
their dependency edges; KernelPrograms and CryptoPrograms (new) and the
native spec and leak registries; mirror pages, ledger, changelog and this
page. No sub-agents.

Resolved scope: [[Native Builtin Kernels]]. Every builtin the audit listed as
refused is native, direct and as a value.

Evidence: each family checked against published or independent references
(Python hashlib, zlib, RFC 8439, OpenSSL-signed RSA and P-256 signatures,
published CRC and FNV check values); buffer, column, sort, flat-table and
codec programs match the interpreter byte for byte including refusals; the
focused groups pass 200 properties each at -O0 and the leak runs release every
allocation. Kernel C compiles under -std=c11 -pedantic -Wall -Wextra -Werror.
All 800 unoptimized test groups and the canonical 20-gate run (`test/gates.sh`
at -O2) passed clean with zero warnings.

Not done: the ledger row stays Partial until independent review; Windows
evidence for fixed seeds is pending as before.

Exact next action: request the independent implementation and wiki-parity
review of #842.

## Referenced by

[[handoffs/_MOC]]
