---
type: handoff
status: IN_REVIEW
issue: 565
aliases: [Native Bytes Delivery]
---
# Native Bytes Delivery

Role transitions: Backend Engineer → Test Engineer → Forensic Guardian
(self-audit only; independent review remains pending). Work continues in
`feature/565-native-bytes` in the backend-performance checkout. No sub-agents.

Ownership: the existing uncommitted Bytes slice and its matching module
mirrors; additional changes are bounded to Lower/Bytes, Lower/Scalar, Lower/Constant and BytesPrograms
and their mirrors, plus dedicated Bytes registration in NativeSpec and TextLeakSpec. Preserve unrelated checkouts and the full release gate.

The latest Claude session left the byte implementation uncommitted. This
continuation adds frozen Bytes projection, E7001 unary-byte refusals, total
receiver selection, and a focused Bytes test lane. Arbitrary byte values,
UTF-8 boundaries, NUL, temporary views, capture snapshots, shared borrows,
argument order and byte entry results have explicit expected outputs. Direct
ordered byte operators retain the interpreter's E7001; tuple/key ordering
compares byte contents.

Validation: changed modules rebuild under GHC 9.14.1 with `-Werror`. The
focused lane runs success, runtime-refusal and counted-allocation properties
under Clang, GCC 15, ASan/UBSan and the tree evaluator. The E6001 refusal-span
property and all five native-progress tests pass. The earlier cancellation
readiness failure passes when isolated. No full release gate was run during
this iteration; the gate and GitHub workflows are unchanged. Independent
implementation, architecture and vault review remain pending. No merge or
release is authorized by these focused results.

Fast loop (from this checkout):

```sh
cabal build pudu:exe:pudu pudu-tests:test:pudu-test --builddir=dist-fast --ghc-options=-Werror
PUDU_TEST_MATCH='native Bytes' "$(cabal list-bin pudu-tests:test:pudu-test --builddir=dist-fast)"
```

The complete C11 goal remains active. BigInt/Decimal, print Results, omitted
defaults, method values, higher-kinded/dynamic values, mutable writeback,
remaining constants, host services, FFI and concurrency remain in the ledger.

Exact next action: implement print as a real Result-valued Core/frame
operation using differential closed-output tests for GHC handle failure
behavior, retaining the existing scalar closed-pipe regressions.

## Referenced by

[[handoffs/_MOC]] · [[Compiler Lower Bytes]] · [[Backend Bytes Programs]] ·
[[Compiler Lower Constant]] · [[Backend Native Tests]]
