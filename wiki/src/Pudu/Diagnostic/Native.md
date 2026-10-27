---
type: module
path: "@root/src/Pudu/Diagnostic/Native.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Diagnostic Contracts]
---
# Native Diagnostic Contracts

Export nativeRefusal, toolchainNotFound, toolchainInvocationFailed,
toolchainTimedOut, toolchainRejected and toolchainPublishFailed. They own
E6001 through E6006 respectively and return ordinary Diagnostic errors with
the caller's source span. No native command or process execution is added.

E6001 names the unsupported construct; E6002 names the compiler search;
E6003 preserves the start failure; E6004 reports the wait bound in seconds;
E6005 preserves the caller-supplied captured output; E6006 preserves the
publication failure. E6001/E6002/E6004/E6005 carry actionable help. None adds
related spans. This projects the existing completion branch's wording.

## Resolved Grill Log

- Code literals are closed and validated by the diagnostic registry gate.
- Keep source snapshot/span identity; never fabricate an environment source.
- Process discovery, capture limits, timeout and atomic publication belong to
  later toolchain integration, not these value constructors.
- Preserve caller detail, Unicode and internal newlines. No host IO occurs here.
- This independent review partition keeps #486 and native execution delivery open.

## Referenced by

[[src/_MOC]] · [[Native Diagnostic Contracts Delivery]] · [[Diagnostic Model]]
