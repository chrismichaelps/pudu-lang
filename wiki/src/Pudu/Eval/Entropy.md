---
type: module
path: "@root/src/Pudu/Eval/Entropy.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, randomness, security]
aliases: [Eval Entropy]
---
# Eval Entropy
## Purpose
Obtain cryptographically strong bytes from the host operating system without exposing host failures.
## Interface
Exports one bounded `secureBytes` operation returning `IoOutcome ByteString`.
## Governance and algorithm
The `entropy` package selects the platform entropy provider. Counts are validated before allocation;
host exceptions become `IoFailed`; no deterministic or clock-based fallback exists.
## Grill Log
- **Q:** Read `/dev/urandom` directly? **A:** No. _Rationale:_ Pudu targets more than Unix and the
  selected dependency owns the platform-specific provider. _Rejected:_ `System.Random`; clock seeds;
  an unbounded allocation request.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Std Random]] · [[Eval Effect]]
