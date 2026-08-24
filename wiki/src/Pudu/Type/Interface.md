---
type: module
path: "@root/src/Pudu/Type/Interface.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.76
depth_status: DEEP
coupling: 5.0
interface_stability: 0.7
tags: [module, deep]
aliases: [Type Interface]
---

# Type Interface

## Purpose

Project a parsed module into the exported type/signature facts and implementation signatures that another module may type-check against, while preserving canonical declaration identity and privacy.

## Interface

### Signatures

```haskell
data TypeInterface
data ImportTypes = ImportTypes
  { importedInterfaces :: ![TypeInterface]
  , importedNames :: !(Map Text NominalId)
  , importedValues :: !(Map Text Text)
  , importedTraits :: !(Set NominalId)
  }

interfaceSkeleton :: Module -> TypeInterface
importsFor
  :: Map ModuleName TypeInterface
  -> Module
  -> ImportTypes
```

### Governance

- Every exported nominal type and trait has a canonical identity formed from its declaring `ModuleName` plus declaration name. Display spelling is separate from equality.
- The interface exposes annotated exported function/constant signatures, exported record/sum/alias shapes required to check their use, exported trait member signatures/default availability, and coherent implementation signatures defined by the module. Exported constants must be annotated with `E3010` otherwise because their bodies are not interface data.
- Function and method bodies, private top-level names, local scopes, inference substitutions, and checker diagnostics are not interface data.
- An implementation has no export marker. It is visible through the defining module interface only when its trait is in the importing module's trait scope; ownership/coherence was already checked in its defining module.
- Selected imports bind only selected exported names. A module or alias import supplies qualified access to all exported names. Import bindings never become exports of the consumer.
- Selecting a missing or private item reports `E2013` at the item span with the named module in the message.
- Imported names map their local spelling/path to canonical identity. Two modules exporting `User` or `Show` never share a type, trait, bound, implementation, or method key.
- Interface skeleton construction is body-independent, allowing all skeletons in a cyclic SCC to exist before any body is checked.
- Every interface-carried function, exported trait member, and implementation method must annotate every parameter and its return type. `E3010` rejects an incomplete ABI signature, and the incomplete member is omitted from the body-free interface so consumer inference cannot invent a context-dependent replacement.
- Private nominal declarations are retained only as non-importable formation shells. They canonicalize private identities mentioned behind public signatures without entering the export or value namespaces.

### Linkage

- **Requires:** [[Syntax Tree]], [[Syntax Name]], [[Type Value]], [[Type Env]], [[Type Formation]], [[Type Check Method]], [[Diagnostic Model]], [[architecture/SEMANTICS]].
- **Consumed by:** [[Compiler Program]], [[Type Check]], [[Type Formation]], [[Type Check Method]].

## Algorithm

Collect exported declarations by namespace and assign canonical identities. Retain private type/trait declarations separately as formation-only shells. Strip function and method bodies only when their ABI signatures are complete, while recording trait-default availability separately. Record each implementation head and its complete stripped methods under canonical trait and target identities. For a consumer import list, build local-spelling-to-canonical type/value maps and include implementation methods only for traits the import placed in scope; [[Semantic Interface]] owns selection diagnostics.

## Negative Logic (Prohibited Paths)

- No filesystem access, module discovery, body checking, evaluation, basename keys, private-name leakage, implicit re-export, or mutation of a dependency's interface.
- No conversion of an alias into nominal identity; aliases remain transparent after canonical lookup.
- No global instance scan detached from imports; method availability follows the loaded dependency interfaces and Pudu's in-scope-trait rule.

## Edge Cases

- Importing `User` without `Show` forms the type but does not make `Show` methods candidates.
- Importing a module under alias `X` maps `X.User` and `X.Show` to the same canonical declarations as their original module path.
- Two selected items with the same local spelling conflict in name resolution; the type interface does not pick one.
- An exported alias may expose a private underlying nominal identity in signatures without making that private name directly importable.
- A trait default may be inherited by an imported implementation even though its body is not checked again in the consumer.
- A default trait and its implementation may come from different dependency interfaces; installation builds one canonical trait table for the whole imported set before installing implementations.
- Two visible traits that provide the same method for one concrete target produce `E3013`; interface installation never resolves the collision by import order.

## Depth

DEPTH 0.76 (DEEP). It hides export projection, body stripping, canonical identity, import-shape interpretation, privacy checks, trait-scope filtering, and merge policy behind two constructors.

## Grill Log

- **Q:** Store dependency ASTs or an interface projection? **A:** A body-free interface projection. _Rationale:_ consumers need signatures, shapes, and implementations but must not re-check or own dependency bodies. _Rejected:_ whole AST; only exported names, which cannot type-check fields, constructors, or methods.
- **Q:** Is a nominal identity its final text segment? **A:** No; it is declaring module plus name. _Rationale:_ [[architecture/SEMANTICS]] defines nominal equality by declaration identity. _Rejected:_ basename maps; import-local spelling as identity.
- **Q:** Are all dependency implementations globally visible? **A:** No; an implementation is considered only when its trait is in the consumer's scope. _Rationale:_ Pudu's lookup rule explicitly considers in-scope traits and avoids spooky action from unrelated imports. _Rejected:_ process-global instance table; target-only lookup.
- **Q:** Can private shapes be omitted entirely? **A:** Private names are not importable, but enough underlying shape may remain behind an exported alias/signature. _Rationale:_ an interface must type-check public promises without granting source-level access to hidden names. _Rejected:_ leaking private bindings; making exported aliases opaque despite transparent alias semantics.
- **Q:** Should a consumer re-run orphan/duplicate checks on imported implementations? **A:** No. _Rationale:_ coherence belongs to the defining module; the program boundary only combines already-valid interfaces and later general overlap checks canonical heads. _Rejected:_ treating imported impls as local declarations.
- **Q:** Can a body-free member omit an ABI annotation and be inferred again by each consumer? **A:** No; report `E3010` in the defining module and omit the incomplete member from its interface. _Rationale:_ its body is absent, so fresh consumer variables would make the signature contextual and unsound, especially across cycles. _Rejected:_ reconstructing a fresh scheme from incomplete syntax; carrying executable bodies in the static interface.

## Variants

- A serialized interface may later replace the in-memory projection without changing import semantics.
- Runtime/link interfaces can carry executable bodies separately from this static interface.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Compiler Program]] · [[Type Check]] · [[Type Formation]] · [[Type Check Method]]
