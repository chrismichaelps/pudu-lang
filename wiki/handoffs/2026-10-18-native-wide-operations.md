---
type: handoff
status: ACTIVE
issue: 503
aliases: [Native Wide Operation Delivery]
---
# Native Wide Operation Delivery

Delivery Owner → Language Architect → Backend Engineer.
[[Native Wide Operations]] and its complete Planned module/test mirrors resolve
ready #503. Own Runtime.Integer.Wide.Operations, WideOperationsSpec, both Cabal
registrations, test runner and matching mirrors. No subagents execute. Preserve
unrelated dist-ticky. Prior locally validated #502 is 88e0b4c2, with all 19 clean
gates/672 groups, both C compilers and sanitizer checks passing.

Use fresh feature/503-native-wide-operations stacked on 88e0b4c2 because native
prerequisites are not on dev. Prepared architecture/mirror files belong only to
#503; no implementation has been created yet. Source admission and production
ABI remain unchanged. Independent implementation/architect/Forensic Guardian
review, supported-platform evidence and dev integration remain promotion gates.

Implement actual-sign checked/wrapping/saturating arithmetic, division versus
remainder refusal identity, bitwise operations and platform-Int checked shifts.
Retain overflowing negative-zero direction. Prove mathematical Integer answers
and exact supplied-site routing with real C; primitive stubs do not prove final
source diagnostic text/effect/cleanup parity. Frame, print/status and public
Int128/UInt128 admission remain required subsequent integration, alongside all
other full-emission ledger obligations.

Exact next action: implement Wide.Operations from its resolved mirror, then
register and execute WideOperationsSpec's independent mathematical/refusal and
minimal-helper corpus before full regression validation.

## Referenced by

[[handoffs/_MOC]] · [[Native Wide Operations]] · [[Native Wide Integer Delivery]]
