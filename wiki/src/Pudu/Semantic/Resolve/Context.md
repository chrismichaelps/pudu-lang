---
type: module
path: "@root/src/Pudu/Semantic/Resolve/Context.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.72
depth_status: DEEP
coupling: 5.0
interface_stability: 0.9
tags: [module, deep]
aliases: [Resolve Context]
---

# Resolve Context

## Purpose

Own the resolver's private state and the primitives that thread it: a pure `Resolver` monad over an explicit state record, scope-frame management, symbol introduction with same-frame duplicate and outer-shadow classification, ambiguous-variant marking, and the value/type name resolution that the [[Name Resolution]] facade walks.

## Interface

### Signatures

```haskell
data ResolveState
data ResolverProducts = ResolverProducts
  { producedSymbols     :: ![Symbol]
  , producedReferences  :: ![Reference]
  , producedDiagnostics :: ![Diagnostic]
  }
newtype Resolver a
runResolver     :: Resolver a -> ResolverProducts
inScope         :: Resolver a -> Resolver ()
insideLoop      :: Maybe (Located Text) -> Resolver a -> Resolver a
outsideLoops    :: Resolver a -> Resolver a
resolveLoopTarget :: Text -> Span -> Maybe (Located Text) -> Resolver ()
declareBuiltin        :: Namespace -> Text -> Resolver ()
declarePreludeName    :: Namespace -> Text -> Resolver ()
declareNamed          :: Namespace -> SymbolOrigin -> Visibility -> Bool -> Located Text -> Resolver ()
recordVariantSymbol   :: Located Text -> Resolver ()
markAmbiguousVariant  :: Text -> Resolver ()
resolveValueName :: Span -> Text -> Resolver ()
resolveTypeName  :: Span -> Text -> Resolver ()
```

### Governance

- The `Resolver` is a hand-written `State -> (a, State)` monad with explicit `Functor`, `Applicative`, and `Monad` instances. It threads `ResolveState` explicitly so the resolver never mutates shared state and a discarded scope leaves nothing behind.
- `runResolver` is the single exit: it runs the action from a fixed `initialState` and freezes the reversed accumulator lists into the products consumed by [[Name Resolution]]. Diagnostics are sorted through `sortDiagnostics` here, once, so every consumer sees the same ordering without re-sorting.
- Loop labels live on their own stack rather than in the lexical scope, because they are not names: nothing evaluates a label, nothing shadows a value with one, and a label is legal only in the two statements that can name it. The stack runs innermost first, which is the order `break` searches.
- `resolveLoopTarget` reports `E2016` for a `break` or `continue` outside every loop and `E2017` for one naming a label no enclosing loop carries. Both were previously runtime failures; a jump with no loop to act on is not a program that works on some input, so it is rejected before it runs.
- `insideLoop` warns `W2002` when a label repeats one already enclosing it. The program still means something definite — the inner label is nearer and wins — but the outer loop has become unreachable by name, which is a mistake in the making rather than a plan.
- `outsideLoops` clears the stack for a function body, so a closure written inside a loop is not treated as inside it. The closure may outlive the loop entirely, and a `break` in one has nothing to leave.
- `inScope` pushes a lexical frame for the duration of an action and pops it on exit. A nested scope's declarations cannot leak outward, which is the structural guarantee that makes `let x = x` see the outer binding.
- `declareBuiltin` binds a wired-in name at `BuiltinOrigin` with `Private` visibility; `declarePreludeName` binds a prelude name at `PreludeOrigin`. The origin distinction is what lets a module declaration shadow a prelude name without conflict or warning while a wired-in name is never displaced.
- `declareNamed` is the general introduction path. It delegates to `introduce`, which reports a same-frame duplicate as `E2001` with the earlier declaration attached as a related span, and an outer shadow as `W2001` only when the displaced binding is one the language warns about — a `var`, parameter, import, or type name. An immutable local shadowing another immutable local is silent and legal.
- `recordVariantSymbol` binds a variant as a value name so an unqualified variant resolves while its spelling is unambiguous; `markAmbiguousVariant` records that two types share a spelling so a later use reports `E2012` and asks for qualification rather than resolving to whichever declaration was seen last.
- `resolveValueName` checks ambiguity first: an ambiguous variant spelling reports `E2012` once and does not resolve. Otherwise it looks in the value namespace and falls through to the type namespace, which is how a qualified path such as `Outcome.Ok` reaches its declaring type. An unresolved value name reports `E2010`.
- `resolveTypeName` looks in the type namespace only; an unresolved type name reports `E2011`. There is no value-to-type fallthrough, because a type position never names a value.
- `freshId` is the sole source of `SymbolId` values, so every symbol has a unique identity and every reference points at exactly one symbol.
- A recovered `InvalidDeclaration`, `InvalidExpression`, or `InvalidPattern` never reaches these primitives, so a parse error cannot produce a second resolution diagnostic for the same defect.

### Linkage

- **Requires:** [[Scope Model]], [[Symbol Model]], [[Diagnostic Model]], [[Semantic Prelude]], [[Syntax Tree]], [[architecture/SEMANTICS]].
- **Consumed by:** [[Name Resolution]] (the facade that drives the walk).

## Algorithm

`ResolveState` holds four reversed accumulators — symbols, references, diagnostics, and the ambiguous-variant list — plus the scope stack and a monotonic identifier counter. Each declaration or reference call appends to the head of the relevant list; `runResolver` reverses them once at the end. Scope changes go through `modifyScopes`, which applies a `ScopeStack -> ScopeStack` transform to the state field. Name resolution reads the current stack through `lookupCurrent`, which delegates to [[Scope Model]]'s innermost-first `lookupSymbol`.

## Negative Logic (Prohibited Paths)

- No type inference, no trait method selection, no exhaustiveness, no ownership or borrow analysis, no constant evaluation, and no cross-module loading. These primitives resolve names and classify conflicts; meaning that requires types is left to typing.
- No reordering of declarations: the facade decides collection and walking order; this module only records what it is told.
- No partial functions: a pop on an empty stack yields an empty stack, and an unresolved name reports a diagnostic rather than crashing.

## Edge Cases

- A duplicate in the same frame reports `E2001` with the first declaration's span as a related note; a shadow across frames warns `W2001` only for the origins [[architecture/SEMANTICS]] lists, so an immutable-over-immutable shadow is silent.
- A variant marked ambiguous before any body is walked reports `E2012` at every use, so qualification is required consistently rather than depending on declaration order.
- A value name that is also a type name resolves in the value namespace first, which is why an unqualified variant (a value) and its type (in the type namespace) do not collide.
- `ResolverProducts` is produced exactly once per module; a partial run is impossible because `runResolver` runs the full action from `initialState` to completion.

## Depth

DEPTH 0.72 (DEEP). It hides the monad threading, the four accumulators, the duplicate-versus-shadow classification, the ambiguity gate, and the value-to-type fallthrough behind a small set of named primitives.

## Grill Log

- **Q:** Should the resolver be a `ReaderT` over `IO`, or a pure state monad? **A:** Pure state monad. _Rationale:_ resolution must be deterministic, total, and free of side effects; a discarded scope must leave no trace, and a pure state value makes that structural. _Rejected:_ `IO`-based resolution; a mutable `IORef` environment with an undo log.
- **Q:** Separate the context/state primitives from the walk, or keep them in the facade? **A:** Separate. _Rationale:_ the facade's responsibility is the walk order and the policy decisions about what each declaration form binds; the state threading and conflict classification are a distinct concern that grew past the facade's clarity budget. Splitting keeps the facade readable and the primitives testable in isolation. _Rejected:_ inlining everything in `Resolve.hs`, which would push the facade past the 500-line delivery limit and entangle walk order with monad mechanics.
- **Q:** Should `runResolver` sort diagnostics, or leave that to the consumer? **A:** Sort here, once. _Rationale:_ the diagnostic model's ordering contract is total and deterministic; sorting at the single exit guarantees every consumer sees the same order without re-sorting or risking divergence. _Rejected:_ deferring sort to [[Name Resolution]] or to [[Compiler Pipeline]].
- **Q:** Should an ambiguous variant resolve to the first declaration seen? **A:** No; report `E2012`. _Rationale:_ picking one silently would make the resolved symbol depend on declaration order, which the two-pass design exists to avoid, and a later refactor would silently change meaning. _Rejected:_ first-wins; last-wins; a warning that still resolves.

## Variants

- Cross-module resolution replaces the opaque import symbol with a real one; the `Resolver` monad and its accumulators do not change shape, only the `SymbolOrigin` values that reach `introduce`.

## Referenced by

[[src/Pudu/Semantic/_MOC]] · [[Name Resolution]] · [[Scope Model]] · [[Symbol Model]] · [[Semantics]]
