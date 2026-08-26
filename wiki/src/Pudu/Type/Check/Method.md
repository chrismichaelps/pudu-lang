---
type: module
path: "@root/src/Pudu/Type/Check/Method.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.55
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Type Check Method]
---

# Type Check Method

## Purpose

Give an implementation's functions the types they have as methods of their target, let an implementation inherit the trait defaults it does not override, bind trait members under the trait's own name so a bounded parameter can find them, register and discharge the trait obligations a call raises, and resolve a method on a nominal type or a bounded rigid parameter.

## Interface

### Signatures

```haskell
declareMethods :: DeclaredTypes -> Map NominalId [Located Function] -> Impl -> Checker ()
declareInterfaceMethods :: DeclaredTypes -> Map NominalId [Located Function] -> Set (NominalId, Text) -> Impl -> Checker ()
declareTraitMembers :: DeclaredTypes -> Trait -> Checker ()
declareBounds :: DeclaredTypes -> Function -> [(Text, [NominalId])]
declareBuiltinConstructors :: Checker ()
dischargeObligations :: Checker ()
methodScheme :: Span -> Type -> Text -> Checker (Maybe Scheme)
functionRigid :: Function -> [Text]
implAliases :: DeclaredTypes -> Impl -> DeclaredTypes
traitTable :: DeclaredTypes -> [Located Declaration] -> Map NominalId [Located Function]
```

### Governance

- A trait's own type parameters are rigid inside its members, exactly as a function's are inside its body. Without that they were formed as nominal types named after the parameter, so `trait Holds[T]` gave `get` a result of some type literally called `T` that nothing could be, and every use reported `expected Int, found T`.

- Two traits may declare the same member for one type. Declaring both is legal; only an unqualified call has to choose, so the ambiguity is recorded when the second implementation binds and reported at the call that cannot resolve it, naming both qualified forms.

- A bound naming a compiler-controlled marker is proved by [[Type Marker]] from the type's structure when no implementation was written, which is what lets `Int` satisfy `Copy` without any module declaring it.

- A method is bound under a key naming the type it implements for, not at module scope. A trait method is reached through a value, which is why `show(user)` does not resolve while `user.show()` does.
- `Self` inside an implementation is its target type. That is what lets a method read the fields of the value it was called on, and it is why the alias is installed before the body is checked.
- `Self` inside a trait member body is a rigid parameter added to the rigid list, so `formType` produces `RigidType "Self"` and method calls route through `rigidMethod` and the trait bound `selfBoundAsBound` installs. The implementing type is unknown while the trait is checked, so `Self` cannot be aliased to a nominal type there.
- A trait member that carries a body is a default. An implementation that does not provide its own gets it, bound at the target type exactly as an overriding method would be.
- `declareTraitMembers` binds a trait's own members under the trait's name with `Self` rigid, so a call on a parameter bounded by that trait finds them through `methodScheme`'s rigid path.
- `declareBounds` collects the trait bounds a function's generic parameters carry from both the parameter list and the `where` clause, since [[grammar/pudu]] gives them the same meaning; these become the obligations a call must prove.
- A method scheme retains both the implementation's parameter bounds and the method's own bounds.
  Dropping the implementation bounds made `impl[N: Integer] Sequence[N, N] for Range[N]` enforce
  `Integer` inside the method body but not when a caller selected that method, so a floating range
  incorrectly satisfied the protocol.
- `dischargeObligations` proves every obligation a call registered, after the enclosing function's body is checked and while the declaration's own parameter bounds are still in scope. A rigid parameter satisfies a bound its own declaration declared; a nominal type satisfies one through its implementations; an unsolved variable proves nothing and is left alone; `E3012` reports an unsatisfied bound.
- Obligations are deduplicated after substitution is resolved. Two protocol methods may impose the
  same bound through different fresh variables that both settle to `Float64`; the caller made one
  mistake and receives one `E3012`, not one per method inspected.
- `declareBuiltinConstructors` binds `Some`/`None`/`Ok`/`Err` before the module's own declarations, so a module that declares its own `Ok` shadows the binding rather than colliding with it.
- `methodScheme` finds a method on a nominal type through its implementations or on a rigid parameter through the traits its bounds declared, which is what a bound is for. When two or more bounds provide the same member, the lookup is ambiguous and reports `E3013` rather than silently picking the first.
- [[Type Check Coherence]] rejects orphan implementations and duplicate implementation heads after method signatures are collected; general unification overlap remains a separate resolved-type slice. Nothing here silently picks between candidates.
- [[Type Interface]] supplies complete body-free imported method schemes keyed by canonical target and trait identity. They are installed only for traits the consumer placed in scope, before local method signatures are added. A second imported scheme or a later local implementation at the same canonical target/member key reports `E3013` rather than overwriting the visible provider; exact duplicate local heads remain [[Type Check Coherence]]'s `E3015` responsibility.

### Linkage

- **Requires:** [[Type Env]], [[Type Interface]], [[Type Formation]], [[Type Value]], [[Syntax Tree]], [[architecture/SEMANTICS]].
- **Consumed by:** [[Type Check]].

## Algorithm

Form the implementation's target, bind each of its functions under the target's method key with `Self` aliased to the target and with implementation-plus-method bounds retained in its scheme, then bind every trait default the implementation did not override. For a trait, bind its members under the trait's own name with `Self` rigid and retain trait-plus-member bounds. For a function, collect its parameter bounds; at each call site, instantiation registers the obligations the bounds impose; after the body, discharge them by checking the resolved argument type against the trait, through `implementsTrait` for a nominal type or `rigidSatisfies` for a rigid parameter.

## Negative Logic (Prohibited Paths)

- No general unification-overlap checking, dynamic dispatch, associated types or constants, or filesystem/module traversal. Cross-module schemes arrive through [[Type Interface]]; orphan ownership and exact duplicate-head rejection are delegated to [[Type Check Coherence]].

## Edge Cases

- An implementation whose target is not a named type contributes no methods rather than inventing a key.
- A default and an override with the same name bind once, with the override winning, because the override is bound first and the default is filtered out.
- Imported default lookup uses the combined canonical trait table, so the trait declaration and implementation may be owned by different modules.
- A local implementation colliding with an imported visible provider is ambiguous even though local signatures are installed later; binding order is never a dispatch preference.
- An unsolved variable at discharge time proves nothing and is left alone rather than guessed at.
- An `ErrorType` at discharge time is skipped, because the argument's own error already explains the failure.

## Depth

DEPTH 0.55 (MEDIUM). It hides method keying, `Self` aliasing, and default inheritance behind two calls.

## Grill Log

- **Q:** Should methods live at module scope? **A:** No; they are keyed by their target type. _Rationale:_ two types may implement the same trait, and a flat scope would make one shadow the other. _Rejected:_ flat method names; a global method table keyed by name alone.
- **Q:** Field or method when both spell the same name? **A:** The method, in callee position only. _Rationale:_ `value.name()` reads as a call, and a field holding a function can still be called by parenthesizing it. _Rejected:_ field always wins, which makes a method unreachable; method always wins, which hides a field.
- **Q:** What should `methodScheme` return when bounds are ambiguous? **A:** `Just (monotype ErrorType)`, not `Nothing`. _Rationale:_ `checkCallee` falls through to `checkExpression` on `Nothing`, which re-enters `rigidMethod` and reports `E3013` a second time. Returning an error scheme keeps the call site typed as an error and stops the duplicate. _Rejected:_ returning `Nothing`, which duplicated the diagnostic; suppressing `E3013` in `rigidMethod`, which would lose the diagnostic for non-call member access.
- **Q:** Can imported methods reuse `Owner.Method` basename keys? **A:** No; keys carry canonical owner identity and member spelling. _Rationale:_ `A.User.show` and `B.User.show` must never collide. _Rejected:_ last-segment owner keys; import-local aliases in method keys.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]] · [[Type Check Coherence]] · [[Evaluator]]
