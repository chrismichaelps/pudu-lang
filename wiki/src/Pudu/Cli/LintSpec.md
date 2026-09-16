---
type: module
path: "@root/test/Pudu/Cli/LintSpec.hs"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, cli, lint]
aliases: [Pudu CLI Lint Spec]
---

# Pudu CLI Lint Spec

## Purpose and evidence

Exercise project configuration, file and next-line suppression, malformed policy, deterministic
directory discovery, JSON completeness, compiler-error preservation, and atomic `--fix` behavior in
isolated temporary projects.

## Grill Log

- **Q:** Test only pure argument parsing? **A:** No. _Rationale:_ discovery, manifests, persistence,
  and recompilation are the failure boundaries a production command must survive.

## Referenced by

[[Pudu CLI Lint]] · [[Repository Test Runner]] · [[Pudu Test Cabal Manifest]]
