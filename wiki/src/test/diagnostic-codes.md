---
type: gate
path: "@root/test/diagnostic-codes.mjs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
tags: [test, diagnostics, lint, registry]
aliases: [Diagnostic Code Gate]
---

# Diagnostic Code Gate

## Purpose and interface

Scan compiler Haskell modules for diagnostic-code literals and reject accidental reuse of one code
for unrelated meanings. The checked `shared` registry is the explicit exception list: every entry
states why all sites represent the same user-facing condition.

Lint deliberately adds two non-reporting sites for existing warnings. [[Pudu Lint Config]] validates
policy against the compiler's closed warning vocabulary, while [[Pudu CLI Lint]] adapts the same
compiler warning to a stable rule name and output schema. Those sites must retain the original code;
assigning a second code would break suppression and machine-output identity.

## Governance

An exception is valid only for one semantic condition crossing implementation boundaries. The gate
also rejects stale exceptions once a code returns to one module, so this registry cannot become an
unchecked allow-list.

`E7005` is shared by checked integer operators and range extent methods. Both mean that a computed
integer result cannot be represented by the operation's declared fixed-width result type; the
operation-specific wording does not change that identity.

E7010 is shared by the interpreter and native emitter for the same
non-terminating Decimal quotient, with identical message/help. Resolved
Grill Log: register this integration condition explicitly, as tracked in
PR #807; do not rename or suppress a reporting site.
`E7010` means a Decimal quotient has no exact base-ten expansion, in the
interpreter and native frame emitter. Both retain the same message and help.
Resolved Grill Log (#806): register this existing shared condition instead
of assigning a backend-only code or suppressing either reporting module.

`E7013` means a sequence pattern's length does not match the value it was
given, in the interpreter and native body lowering. Both retain the same
message and help. Resolved Grill Log (#846): the native form reaches the same
run-time condition as the tree walker, so it reports the same code rather than
a backend-only one; the leak harness now also compiles against a piece of
instrumentation that defines its own POSIX feature macros, which the emitted
prelude no longer overrides.

## Grill Log

- **Q:** Ignore the lint modules wholesale? **A:** No. _Rationale:_ explicit per-code declarations
  keep new warning reuse auditable and preserve the stale-exception check.
- **Q:** Mint lint-only aliases for compiler warnings? **A:** No. _Rationale:_ users need one stable
  identity across `check`, human lint output, JSON, fixes, and suppression policy.
- **Q:** Give range extent overflow a new code? **A:** No. _Rationale:_ `E7005` already means a
  computed integer result does not fit its declared kind, whether the computation is an operator,
  `Range.length`, or `Range.sum`. _Rejected:_ splitting one recovery category by call syntax.
- **Q:** Give derive ownership, overlap, contract and budget failures codes of their own?
  **A:** No. _Rationale:_ E3014 and E3015 mean ownership and overlap for authored impls and
  generated heads alike; E3091 is a derive contract violation and E3093 a derive instantiation
  exceeding its bounds wherever found. _Rejected:_ splitting one meaning by which phase found it.

E7015 is shared by the interpreter's foreign bridge and native foreign call sites, which stop with the same words when a library does not open or a symbol is missing (#850).

E7017, E7024 and E7025 are shared by the bridge and native foreign call sites (#851).

E7020, E7021 and E7022 are shared by the interpreter and native handle
boundary for null results, conflicting ownership claims and invalid handle use.

## Referenced by

[[test gates]] · [[Pudu Lint Config]] · [[Pudu CLI Lint]]
