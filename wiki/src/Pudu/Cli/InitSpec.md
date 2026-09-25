---
type: module
path: "@root/test/Pudu/Cli/InitSpec.hs"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, cli, initialization]
aliases: [Pudu CLI Init Spec]
---

# Pudu CLI Init Spec

## Purpose and evidence

Exercises package-name normalization and project initialization in isolated temporary directories.
Normalization cases include names with doubled letters (`hello`, `letter`, `book-keeper`, `app2`,
`aabbcc`), which must survive unchanged: grouping every repeated character rather than only
separators once turned `hello` into `helo`.
Properties cover a fresh complete layered Pudu scaffold, its exact inward imports, preservation of existing source and tests, existing
manifest refusal, incompatible object refusal without partial managed files, reserved/empty package
name refusal, and a concurrent lock refusal. Exact file contents and typed errors are compared.
Library properties also read the generated manifest through the compiler parser, require the
identity and root to be accepted by package identity rules, require no local-only self dependency,
and exercise invalid explicit names.

The repository release gate separately invokes the built CLI inside a generated project and proves
`check`, `run`, `test`, `build`, and execution of the bundle. Unit properties do not substitute for
that end-to-end boundary.

## Grill Log

- **Q:** Test only pure template strings? **A:** No. _Rationale:_ the contract is filesystem safety
  and ordering. _Accepted:_ isolated real directories plus the executable release gate. _Rejected:_
  snapshots that never create a project.
- **Q:** Assert only success? **A:** No. _Rationale:_ refusal without overwriting is the highest-risk
  behavior. _Accepted:_ exact typed failure and unchanged-file checks.

Resolved Grill Log: success, preservation, refusal, and concurrency are observable through real
filesystem operations without touching a user's project.

## Referenced by

[[Pudu CLI Init]] · [[Pudu Test Cabal Manifest]]
