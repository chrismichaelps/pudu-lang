---
type: module
path: "@root/src/Pudu/Semantic/Resolve.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.84
depth_status: DEEP
coupling: 7.0
interface_stability: 1.0
tags: [module, deep]
aliases: [Name Resolution]
---

# Name Resolution

## Purpose

Resolve every name in a parsed module to a symbol, or diagnose it, producing the symbol table and reference map that typing and ownership consume.

## Interface

### Signatures

```haskell
data Resolution = Resolution
  { resolutionSymbols :: ![Symbol]
  , resolutionReferences :: ![Reference]
  , resolutionExports :: ![Symbol]
  }
resolveModule :: Module -> (Resolution, [Diagnostic])
```

### Governance

- Resolution is lexical, deterministic, and independent of declaration and import order: every module-scope declaration is collected before any body is walked, so a function may call one declared later without a forward declaration.
- Value and type namespaces are separate. A type name and a value name may spell the same word in one scope without conflict.
- A block binding takes effect *after* its declaration, matching [[architecture/SEMANTICS]]: in `let x = x`, the initializer sees the outer `x`, not the one being declared. Functions are the admitted exception and are visible throughout their scope so recursion works.
- Duplicate declarations in one frame report `E2001` with a related span pointing at the first declaration.
- An unresolved value name reports `E2010`; an unresolved type name reports `E2011`. Each is reported at the offending segment, once.
- Only the first segment of a dotted path is resolved. Later segments are field, member, or variant selections whose meaning requires types, so resolution neither invents nor rejects them.
- Imports never re-export. An alias binds one external symbol in both namespaces; a selection list binds each named item in both namespaces, because which namespace an imported item belongs to is only knowable once cross-module resolution exists. An imported name that collides with a module declaration is an `E2001` conflict.
- Variants live in their type's namespace, so an unqualified variant name does not resolve unless it was imported explicitly; `Result.Ok` resolves through its type. This follows [[architecture/SEMANTICS]] rather than adding an implicit local re-export.
- Shadowing a `var`, a parameter, an import, or a type name warns with `W2001`; an immutable local shadowing another immutable local is silent and legal. Borrow-sensitive shadowing rules belong to ownership checking.
- Scope layering follows Haskell's shape: wired-in names from [[Semantic Prelude]] occupy the outermost frame, the implicitly imported prelude module the next, and the module's own imports and declarations the innermost. An inner layer shadows an outer one silently, so a program that imports nothing still resolves `Int64` and a module may still define its own `Drop`.
- `Self` is bound inside a trait or implementation body only.
- A recovered `InvalidDeclaration`, `InvalidExpression`, or `InvalidPattern` introduces no symbol and no reference, so a parse error never produces a second resolution error for the same defect.

### Linkage

- **Requires:** [[Symbol Model]], [[Scope Model]], [[Semantic Prelude]], [[Syntax Tree]], [[Diagnostic Model]], [[architecture/SEMANTICS]].
- **Consumed by:** [[Semantic]] and future typing, ownership, and lowering phases.

## Algorithm

Push the builtin frame, collect module declarations and imports into the module frame reporting conflicts, then walk each declaration: functions push a frame with type parameters and parameters bound left to right, type declarations push their parameters, traits and implementations bind `Self`. Blocks push a frame and bind each local after its initializer is resolved. Every resolved name appends a `Reference`; every unresolved name appends a diagnostic. An `ArrayExpression` walks each element expression so names inside array literals resolve like any other expression context.

## Negative Logic (Prohibited Paths)

- No type inference or checking, no trait method selection, no exhaustiveness, no ownership or initialization analysis, no constant evaluation, no filesystem or cross-module loading, and no reordering of user declarations.

## Edge Cases

- A module whose header failed to parse never reaches resolution; the phase runs only on a module the parser admitted.
- Default arguments resolve against parameters declared before them, so `fn f(a: Int, b: Int = a)` resolves and `fn f(a: Int = b, b: Int)` reports `E2010`.
- A pattern binding shadows an outer binding for the arm body only; alternation binds each alternative's names in the same arm frame, and whether the alternatives agree is a typing rule.
- A generic parameter shadows a module type of the same name for the declaration that introduced it.

## Depth

DEPTH 0.84 (DEEP). One entry point hides collection order, namespace policy, scope construction for six declaration forms, pattern binding, shadow classification, and reference recording.

## Grill Log

- **Q:** One pass or two? **A:** Two: collect module declarations, then walk bodies. _Rationale:_ [[architecture/SEMANTICS]] requires order independence at module scope, which a single forward pass cannot provide. _Rejected:_ single-pass with forward declarations; lazy fixpoint resolution.
- **Q:** Should an unqualified variant resolve to a locally declared variant? **A:** No. _Rationale:_ variants live in their type's namespace, and inventing a local re-export would make resolution disagree with the normative rule and with cross-module behavior. _Rejected:_ implicit variant import; ambiguity-tolerant lookup.
- **Q:** What happens to the second and later segments of a path? **A:** They are left unresolved by design. _Rationale:_ member and variant selection needs the receiver's type; guessing here would produce errors that typing would have to contradict. _Rejected:_ resolving segments against the module table; rejecting unknown members.
- **Q:** Error or warning for shadowing? **A:** Warning `W2001` for the origins [[architecture/SEMANTICS]] lists, silence otherwise. _Rationale:_ the rule is stated as a lint that may harden later, and hardening it now would reject valid programs. _Rejected:_ hard error; unconditional warning on every shadow.
- **Q:** Do imports resolve to real symbols? **A:** They become opaque external symbols in both namespaces. _Rationale:_ no cross-module loading exists yet, and treating an imported name as unresolved would flood every real program with errors. _Rejected:_ resolving imports against the filesystem; ignoring imports entirely.

## Variants

- Cross-module resolution replaces the opaque import symbol with a real one once a module graph exists; the reference map's shape does not change.

## Referenced by

[[src/Pudu/Semantic/_MOC]] · [[Semantic]] · [[Symbol Model]] · [[Scope Model]] · [[Semantic Prelude]] · [[Syntax Tree]] · [[Semantics]]
