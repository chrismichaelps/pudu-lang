---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Lint/Config.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, tooling, lint, configuration]
aliases: [Pudu Lint Config]
---

# Pudu Lint Config

## Purpose and interface

Parse and apply the closed lint-policy vocabulary. `projectAllowances` reads the nearest
`pudu.toml`; `sourceAllowances` reads standalone Pudu line-comment directives; `warningCode`
validates codes against the set of warning rules implemented by this compiler; and `suppressed`
answers whether one diagnostic is exempt at its exact source line.

The project form is `[lint] allow = ["W2001", ...]`. Source forms are
`// pudu-lint: allow-file CODE...` and `// pudu-lint: allow-next CODE...`. TOML comments are removed
only outside quoted text. Duplicate project keys, malformed arrays/directives, shape-invalid codes,
and shape-valid but unknown codes are visible typed text failures.

## Governance

Policy parsing is strict where silence could disable a rule and permissive toward unrelated
manifest sections and keys. `allow-next` maps one physical line to a code set in a single source
walk; applying policy is logarithmic in distinct directive lines and does not rescan source per
finding.

## Grill Log

- **Q:** Accept any future-shaped `W7xxx` code? **A:** No. _Rationale:_ a typo such as `W7102`
  would otherwise look like an active exception. New rules extend the registry deliberately.
- **Q:** Parse all TOML here? **A:** No. _Rationale:_ the compiler bootstrap needs one closed lint
  table before Pudu code can run. _Accepted:_ the same bounded manifest subset policy used by
  [[Compiler Manifest]].

## Referenced by

[[Pudu CLI Lint]] · [[Pudu CLI Lint Spec]] · [[Pudu Lint]]
