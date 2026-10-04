---
type: module
path: "@root/src/Pudu/Type/Check/Derive.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, types]
aliases: [Type Check Derive]
---

# Type Check Derive

## Purpose and interface

`checkDeriveContracts :: DeclaredTypes -> ImportTypes -> Module -> Checker ()`
checks every local derive against the ordinary canonical trait contract, once
at its definition, even when no request exists. It does not instantiate derives.

## Governance and algorithm

Build one catalog of local and imported trait declarations, keyed by declaring
module and name. Form the derive head with its target parameter rigid and require
an actual trait with the declared argument arity. Index member names once.
Refuse repeated members, extra members, missing required members and declarations
without a body. Defaults may be omitted, including imported defaults whose bodies
were removed from interfaces.

Read each ordinary canonical member scheme already installed by the checker.
Substitute the abstract target for Self and concrete trait arguments for trait
parameters. Alpha-normalize method-local parameters positionally, preserving
kinds. Compare the entire written function contract, including asyncness, borrow
mutability, unsafe requirements and type structure. Additional method bounds must
be implied by the trait contract; a derive cannot strengthen callers' obligations.
All contract refusals use E3091 at the offending member or head. Invalid recovery
types do not cascade into a second signature diagnostic.

## Negative logic

No trait-name special cases, evaluator, source-string construction, field
instantiation, dependency IO, inference over trait signatures or imported body
checking. Keep the catalog local to one check, never in global mutable state.

## Edge cases

Empty traits and default-only traits accept empty derives. Record and Sum derive
definitions for the same trait are distinct; a repeated local trait/shape pair is
refused. Generic traits and alpha-renamed member parameters compare structurally.
Unknown names remain resolution errors. Body checking stays in [[Type Check]]
and runs once under rigid types after contract validation.

## Grill Log

- **Q:** Validate only known standard traits? **A:** Use ordinary canonical
  declarations and installed schemes for every trait. _Rationale:_ user traits
  must receive the same guarantees. _Rejected:_ hardcoded Eq/Json contracts.
- **Q:** Recheck a derive body for every target? **A:** Check the generic definition
  once; contract validation is a separate signature step. _Rationale:_ requests
  cannot specialize away definition mistakes. _Rejected:_ target-driven checking.
- **Q:** Compare source spellings of signatures? **A:** Compare formed types after
  positional substitution. _Rationale:_ aliases, imports and binder renaming must
  preserve meaning. _Rejected:_ source equality or nested span equality.

## Linkage and backlinks

Requires [[Type Env]], [[Type Formation]], [[Type Interface]], [[Type Interface Graph]],
[[Type Substitution]] and [[Syntax Tree]]. Consumed by [[Type Check]].
Referenced by [[src/Pudu/Type/_MOC]] · [[Derive Design]].

## Complete trait evidence

Contract-bound comparison substitutes both the subject and the full trait application, including the implicit target implementation application. Method bound formation includes the abstract target parameter.

Resolved Grill Log: method-local alpha-renaming does not erase a trait parameter or allow a stronger application than the trait contract.
