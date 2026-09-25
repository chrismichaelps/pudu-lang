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

## Grill Log

- **Q:** Ignore the lint modules wholesale? **A:** No. _Rationale:_ explicit per-code declarations
  keep new warning reuse auditable and preserve the stale-exception check.
- **Q:** Mint lint-only aliases for compiler warnings? **A:** No. _Rationale:_ users need one stable
  identity across `check`, human lint output, JSON, fixes, and suppression policy.
- **Q:** Give range extent overflow a new code? **A:** No. _Rationale:_ `E7005` already means a
  computed integer result does not fit its declared kind, whether the computation is an operator,
  `Range.length`, or `Range.sum`. _Rejected:_ splitting one recovery category by call syntax.

## Referenced by

[[test gates]] · [[Pudu Lint Config]] · [[Pudu CLI Lint]]
