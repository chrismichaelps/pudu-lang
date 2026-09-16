---
type: module
path: "@root/src/Pudu/Semantic/Symbol.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 2.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Symbol Model]
---

# Symbol Model

## Purpose

Own the identity of every named entity the resolver introduces: a stable identifier, its namespace, where it came from, and the syntactic facts later phases need.

## Interface

### Signatures

```haskell
newtype SymbolId = SymbolId Int
data Namespace = ValueSpace | TypeSpace
data SymbolOrigin
  = BuiltinOrigin | ModuleOrigin | ImportOrigin | ParameterOrigin
  | LocalOrigin | TypeParamOrigin | VariantOrigin | FieldOrigin
data Symbol = Symbol
  { symbolId :: !SymbolId, symbolName :: !Text, symbolNamespace :: !Namespace
  , symbolOrigin :: !SymbolOrigin, symbolMutable :: !Bool
  , symbolVisibility :: !Visibility, symbolSpan :: !(Maybe Span) }
data Reference = Reference { referenceSpan :: !Span, referenceSymbol :: !SymbolId }
```

### Governance

- Identity is the `SymbolId`, not the name: two distinct declarations that spell the same name in different scopes are different symbols, which is what makes shadowing representable rather than destructive.
- Value and type namespaces are distinct, matching [[architecture/SEMANTICS]]; a symbol always belongs to exactly one.
- `symbolSpan` is `Nothing` only for builtins, which have no source of their own.
- `symbolMutable` records the declared `var`, not a computed place property; ownership checking derives writability from it rather than re-reading syntax.
- Origin is preserved because the shadowing rule treats parameters, imports, and type names differently from ordinary immutable locals.
- Data only: no scope search, no diagnostics, no resolution policy.

### Linkage

- **Requires:** [[Source]], [[Syntax Tree]], [[grammar/haskell]].
- **Consumed by:** [[Scope Model]], [[Name Resolution]], and future typing and ownership phases.

## Algorithm

No algorithm; strict records with derived equality and ordering on identifiers.

## Negative Logic (Prohibited Paths)

- No type information, no mutable global counter, no name-based equality, no formatting or rendering.

## Edge Cases

- A recovered `InvalidDeclaration` introduces no symbol at all, so a parse error never invents a binding.

## Depth

DEPTH 0.45 (MEDIUM). Small but load-bearing: it is the only place identity, namespace, and declaration facts are defined for every later phase.

## Grill Log

- **Q:** Name-keyed or identifier-keyed symbols? **A:** Identifier-keyed with the name as data. _Rationale:_ shadowing, imports, and generic parameters all reuse names, and later phases must distinguish the entities behind them. _Rejected:_ resolving to `Text`; interning names as identity.
- **Q:** Should the symbol carry a type? **A:** No. _Rationale:_ resolution runs before typing and must not force a placeholder type into existence. _Rejected:_ an `Unknown` type field filled in later by mutation.

## Referenced by

[[src/Pudu/Semantic/_MOC]] · [[Scope Model]] · [[Name Resolution]] · [[Semantics]]
