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
- **An arm whose values an earlier arm already took is the same `W5001`**, with a help line saying which of the two happened. Writing `case Red` twice is a live-looking case that never runs, exactly as an arm after a wildcard is, and a reader who wrote one wants to hear about it as much as the other.
- Only a test whose whole extent is one name or one literal is recorded as taken. `case Ok(1)` names part of `Ok`, so it takes nothing and a later `case Ok(n)` stays reachable — the same rule that already stops `case Ok(1)` from claiming coverage.
- An alternative takes what its branches take, and only when every branch is nameable. `case Red | Green` takes both, so a later `case Red` is dead; a later `case Green | Blue` is not, because it names something new.
- A guarded arm takes nothing, for the reason it covers nothing. It may still be reported unreachable, because an earlier unguarded arm that took its pattern leaves no value for the guard to run on.
- Checking runs after the arms have been typed, so a scrutinee whose type failed produces no coverage complaint on top of the type error.
- Closed sum domains are keyed by canonical `NominalId`, not the displayed basename, so imported sums with the same declaration name retain distinct constructor sets.

### Linkage

- **Requires:** [[Type Env]], [[Type Unify]], [[Type Value]], [[Syntax Tree]], [[architecture/SEMANTICS]].
- **Consumed by:** [[Type Check]].

## Algorithm

Resolve the scrutinee's type, walk the arms once carrying what earlier unguarded arms have taken and whether one of them matched everything, then either enumerate the constructors of a closed domain and name what no unguarded arm covers, or require an irrefutable arm for an open one.

## Negative Logic (Prohibited Paths)

- No usefulness analysis beyond the irrefutable-arm and already-taken rules, no range or literal-domain reasoning, no reachability across guards, and no rewriting of the match. A pattern that binds part of what it matches spans more values than any key could stand for, so nothing is claimed about it in either direction.

## Edge Cases

- A match on a value whose type is still an inference variable is not checked; the type is not yet known, and guessing would produce a diagnostic the reader cannot act on.
- A nested pattern is judged only by whether it binds or tests, so a deeply structured arm never claims more coverage than it has.
- Two modules may each declare `ResultLike`; exhaustiveness reads the constructor set owned by the scrutinee's canonical module-qualified identity rather than whichever basename was collected last.

## Depth

DEPTH 0.55 (MEDIUM). It hides refutability, guard handling, and domain classification behind one call.

## Grill Log

- **Q:** Should a guarded arm count toward coverage? **A:** No. _Rationale:_ the guard decides at run time, so counting it would let a program pass the check and still find no arm. _Rejected:_ counting guarded arms; requiring guards to be total.
- **Q:** Enumerate integer ranges? **A:** No; an open domain needs an irrefutable arm. _Rationale:_ range arithmetic over every integer type is a decision procedure this slice does not have, and a wrong answer here rejects valid programs. _Rejected:_ interval reasoning; treating a literal set as closed.
- **Q:** Why does a repeated case take two forms of the same warning rather than a new code? **A:** Because it is the same mistake to the reader. _Rationale:_ both are a case that looks live and never runs; what differs is how it came to be dead, which is what the help line is for, and a second code would make a reader learn two names for one thing. _Rejected:_ a distinct `W5002`; silence on repeats.
- **Q:** Why record only whole names and whole literals? **A:** Because those are the tests whose extent is exactly known. _Rationale:_ deciding that `case Ok(1)` and `case Ok(n)` overlap needs the payload's domain, which is the same decision procedure this module already declines to have for ranges — and being wrong here reports live code as dead. _Rejected:_ structural subsumption over nested patterns.
- **Q:** Error or warning for an unreachable arm? **A:** Warning. _Rationale:_ the program's meaning is well defined, and the dead arm is a mistake to point out rather than a reason to refuse. _Rejected:_ hard error; silence.

## Variants

- Usefulness analysis over nested patterns and literal ranges extends this module once the decision procedure is worth its weight.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]] · [[architecture/SEMANTICS]]
