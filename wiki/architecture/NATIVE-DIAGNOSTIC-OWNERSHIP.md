---
type: architecture
aliases: [Native Diagnostic Ownership]
tags: [backend, runtime, diagnostics, ownership]
---
# Native Diagnostic Ownership

Dynamic diagnostic messages and computed help must survive frame cleanup,
but their surviving copies must not remain allocated at normal fatal exit.
Current fail_text/fail_text_help allocate a copy and hand it to a terminating
reporter with no release path. Prove that leak with production-emitted source
under allocation accounting before changing ownership.

## Resolved Grill Log

- Extend pudu_fail_report with an owned_payload base pointer. It takes that
  allocation while borrowing the message/help views. Static diagnostics pass
  NULL. Dynamic diagnostics transfer their one copied allocation, even when
  help points into the middle of it.
- Keep frame cleanup before rendering. Render and flush every message/help
  byte before freeing owned_payload exactly once. Restore ordinary SIGPIPE
  policy and exit one in the existing order. No byte, source-site, color or
  fatal-stream policy change.
- Check message.length + help.length before allocation. Overflow reaches the
  existing memory failure boundary before reading either payload. Zero-length
  payloads still own their minimum allocation and release it.
- Runtime revision becomes 16 for the private reporter signature. No public
  syntax, type or evaluator behavior changes.
- Count calloc/malloc/free in real emitted programs. Dynamic E7001, E7008 with
  static help and computed-help E7004 must retain prior stdout, exact code and
  meaningful message/help while exiting one with zero live allocations.
  Separate differential tests still require the complete interpreter bytes.
- OS termination during a fatal write is not a normal fatal exit; this slice
  preserves existing SIGPIPE outcomes and does not claim cleanup after a kill.

## Ownership and evidence

Backend Engineer owns Backend/{Runtime,Runtime/Text}; Test Engineer owns bounded
FrameRuntimeSpec additions and BrokenPipeSpec diagnostic cases. Corresponding
mirrors precede implementation.
Forensic Guardian self-audits parity; independent review remains pending.
No sub-agents. Focused Clang/GCC/sanitizer, dynamic diagnostic parity, frame and
closed-pipe regressions are required; full release gate/workflows are unchanged.
Full-suite/platform/review and remaining emission surfaces stay in the goal.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Native Diagnostic Ownership Delivery]] · [[Native Text Runtime]] · [[Backend Runtime]]
