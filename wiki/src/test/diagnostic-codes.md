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

## Grill Log

- **Q:** Ignore the lint modules wholesale? **A:** No. _Rationale:_ explicit per-code declarations
  keep new warning reuse auditable and preserve the stale-exception check.
- **Q:** Mint lint-only aliases for compiler warnings? **A:** No. _Rationale:_ users need one stable
  identity across `check`, human lint output, JSON, fixes, and suppression policy.

## Referenced by

[[test gates]] · [[Pudu Lint Config]] · [[Pudu CLI Lint]]
