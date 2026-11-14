---
type: handoff
status: HANDED_OFF
issue: 509
aliases: [Native Floating Notice Delivery]
---
# Native Floating Notice Delivery

Language Architect → Tooling/Release Engineer → Test Engineer. This is the
notice/packaging partition of #509, split before the repository's 600-line PR
limit. Own THIRD_PARTY_NOTICES, Cabal license-files, package-binary notice
copying/tests and CI/release/local gate registration plus matching mirrors.
No subagents; preserve unrelated dist-ticky. Do not claim floating admission.

Seven focused packaging tests pass, including exact bytes, old-package absence,
symlink/nonregular refusal and unchanged strip policy. Prototype full-stack
source/binary archives retain identical notice bytes; extracted compiler,
checksum/signature, native UInt128 execution and SQLite checks pass. Evidence:
~/.codex/tmp/pudu-509/artifact-evidence.json. Final clean stack validation follows
the formatter partition; independent reviews/platform evidence remain pending.

Exact next action: finish #509's raw-bit
formatter, exact GHC corpus and source/archive notice equality, and run the full
clean gates. Intermediate PRs use Refs #509 and keep the issue open.

## Referenced by

[[handoffs/_MOC]] · [[Native Floating Notices]] · [[Package Binary]] · [[Package Binary Tests]]
