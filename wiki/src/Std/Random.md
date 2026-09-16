---
type: module
path: "@root/lib/Std/Random.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, randomness, security]
aliases: [Std Random]
---
# Std Random
## Purpose
Provide reproducible pseudo-random generators and a separate operating-system entropy boundary.
## Interface
Exports explicit-state deterministic generation for simulation and tests, plus `secureBytes(count)`
for non-deterministic security material.
## Governance and algorithm
Deterministic functions accept and return `Generator`; they never imply secrecy. `secureBytes`
returns `Result[Bytes, Str]`, rejects negative or excessive requests before allocation, and delegates
to the host operating system's cryptographic entropy service. It does not expose a seed or silently
fall back to the clock.
## Grill Log
- **Q:** Seed the existing generator from the clock for credentials? **A:** No. _Rationale:_ clock
  state is guessable and reproducibility is the deterministic generator's contract. _Rejected:_
  fallback to pseudo-random bytes when OS entropy fails.
- **Q:** Make all random APIs effectful? **A:** No. _Rationale:_ simulations and property tests need
  replayable sequences. _Rejected:_ one ambiguous API serving deterministic and secure use cases.
## Referenced by
[[src/Std/_MOC]] · [[Eval Entropy]] · [[Std Db]] · [[Std Uuid]] · [[architecture/STDLIB]]
