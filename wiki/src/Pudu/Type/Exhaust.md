---
type: module
path: "@root/src/Pudu/Type/Exhaust.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.55
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Type Exhaust]
---

# Type Exhaust

## Purpose

Check that a match covers every value its scrutinee can take, and that no arm is unreachable.

## Interface

### Signatures

```haskell
checkExhaustive :: Span -> Type -> [Located MatchArm] -> Checker ()
```

### Governance

- A guarded arm never contributes to coverage. Its guard may be false, which is exactly the rule [[architecture/SEMANTICS]] states, and treating it as covering would accept a match that fails at run time.
- Coverage is decided only where it is decidable: a closed sum and `Bool` are enumerated, and an open domain such as `Int` or `Str` is covered only by an irrefutable arm. Nothing here pretends to enumerate an infinite domain.
- An arm covers a constructor only when its payload patterns bind rather than test: `case Ok(1)` tests, so it leaves `Ok` uncovered.
- A missing case is `E5001` and names what is missing, because a list of remaining constructors is what the reader needs to act.
- An arm after one that already matches everything is `W5001`, a warning rather than an error: unreachable code is a mistake worth reporting but not a reason to refuse the program.
- Checking runs after the arms have been typed, so a scrutinee whose type failed produces no coverage complaint on top of the type error.

### Linkage

- **Requires:** [[Type Env]], [[Type Unify]], [[Type Value]], [[Syntax Tree]], [[architecture/SEMANTICS]].
- **Consumed by:** [[Type Check]].

## Algorithm

Resolve the scrutinee's type, report arms following an irrefutable one, then either enumerate the constructors of a closed domain and name what no unguarded arm covers, or require an irrefutable arm for an open one.

## Negative Logic (Prohibited Paths)

- No usefulness analysis beyond the irrefutable-arm rule, no range or literal-domain reasoning, no reachability across guards, and no rewriting of the match.

## Edge Cases

- A match on a value whose type is still an inference variable is not checked; the type is not yet known, and guessing would produce a diagnostic the reader cannot act on.
- A nested pattern is judged only by whether it binds or tests, so a deeply structured arm never claims more coverage than it has.

## Depth

DEPTH 0.55 (MEDIUM). It hides refutability, guard handling, and domain classification behind one call.

## Grill Log

- **Q:** Should a guarded arm count toward coverage? **A:** No. _Rationale:_ the guard decides at run time, so counting it would let a program pass the check and still find no arm. _Rejected:_ counting guarded arms; requiring guards to be total.
- **Q:** Enumerate integer ranges? **A:** No; an open domain needs an irrefutable arm. _Rationale:_ range arithmetic over every integer type is a decision procedure this slice does not have, and a wrong answer here rejects valid programs. _Rejected:_ interval reasoning; treating a literal set as closed.
- **Q:** Error or warning for an unreachable arm? **A:** Warning. _Rationale:_ the program's meaning is well defined, and the dead arm is a mistake to point out rather than a reason to refuse. _Rejected:_ hard error; silence.

## Variants

- Usefulness analysis over nested patterns and literal ranges extends this module once the decision procedure is worth its weight.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]] · [[architecture/SEMANTICS]]
