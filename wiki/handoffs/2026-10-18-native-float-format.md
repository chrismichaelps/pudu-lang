---
type: handoff
status: HANDED_OFF
issue: 509
aliases: [Native Binary64 Formatter Delivery]
---
# Native Binary64 Formatter Delivery

Delivery Owner → Language Architect → Backend Engineer → Test Engineer.
#508 is committed as 9e5b7aac after all 19 clean gates/680 groups pass.
[[Native Binary64 Formatter]] resolves exact bit-pattern formatting. Own that
module, FloatFormatSpec and explicit registration. Tooling/Release Engineer owns
THIRD_PARTY_NOTICES, Cabal license-files and package-binary notice copying/tests.
Complete mirrors exist before implementation. No subagents; preserve dist-ticky.

Stack on #508 because dev lacks prerequisite scratch/runtime code. No floating
source/Core/frame admission or runtime ABI revision is included. The full C11
objective and numeric-family obligations remain active.

Preflight: installed locked GHC show outputs are recorded in
~/.codex/tmp/pudu-float/show-oracle.tsv; verified upstream blob/URL are in
upstream-source.json. Both evaluators preserve zero status/empty stderr for
Float64/Float32/Bool entry output with healthy/default/ignored/blocked closed
stdout (24 CLI observations). The formatter itself performs no IO.

Tooling/Release Engineer → Backend Engineer → Test Engineer: notice/CI/gate
partition bbb967f0 is committed (209 additions, 2 deletions). The formatter
partition is separate to stay below the 600-line review limit. Actual Clang,
GCC 15 and ASan/UBSan executions match GHC for 63,661 unique encodings, canaries,
locked spellings and three minimal roots; emitted notice equality passes.
Seven packaging tests pass. Source/binary archive notice bytes, checksum,
signature, extracted compiler/native UInt128 and SQLite checks pass; all evidence
is under ~/.codex/tmp/pudu-509/. No floating source/ABI admission is claimed.

Next-stage preflight: ~/.codex/tmp/pudu-float/arithmetic-probe/ records
4,294 exact GHC/C narrowing encodings and 17,184 paired-width arithmetic
cases per compiler, with zero raw-result/predicate mismatches under Clang
and GCC 15. These host-only probes do not prove C11 portability or source
admission; resolve target assumptions before integrating the arithmetic.

Final clean validation: all 20 gates pass. Fresh -Werror compilation covers
321 production and 129 test modules; the full suite runs 682 groups, including
63,661 formatter encodings and 351 strict C11 frame translations. Progress
checks and five generator tests also pass. Evidence is under
~/.codex/tmp/pudu-509/validation/; the specific gate process is terminal.

Exact next action: resolve and implement typed floating arithmetic/bit transport
under a ready successor issue, then integrate Core/frame/source admission and
entry reporting. Keep the formatter and notice partitions separately reviewable.
No subagents; independent review/platform gates remain open.

## Referenced by

[[handoffs/_MOC]] · [[Native Binary64 Formatter]] · [[Native Binary64 Formatter Tests]] · [[Native Floating Notices]]

Successor [[Native Floating Value Delivery]] owns ready issue #510 and the
active arithmetic prerequisite; preserve the full source-integration obligation.
