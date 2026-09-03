---
type: module
path: "@root/src/Pudu/Type/Check/Import.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.64
depth_status: MEDIUM
coupling: 5.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Type Check Import]
---

# Type Check Import

## Purpose

Install body-free [[Type Interface]] declarations as the outer declared/signature environment consumed by [[Type Check]], without making dependency declarations local or rechecking their bodies/coherence.

## Interface

```haskell
collectImportedDeclared :: ImportTypes -> Checker DeclaredTypes
declareImportedTypes :: DeclaredTypes -> ImportTypes -> Checker ()
```

## Governance

- Each interface is collected under its declaring module, so unqualified source spellings form canonical identities before consumer aliases are overlaid.
- Exported functions, foreign functions, opaque foreign handles, annotated constants, constructors, traits, and implementation methods publish canonical keys; consumer import spelling is only an alias to those keys.
- Imported implementations are installed only when their canonical trait identity is in `importedTraits`.
- Default methods use body-free availability metadata; dependency bodies and coherence checks never enter the consumer.
- Private nominal shells participate in formation under their declaring module but never publish names or constructors.
- Consumer spellings for exported aliases overlay the declaring interface's already-formed canonical alias target; aliases remain transparent instead of becoming fresh nominal identities at the import boundary.
- One canonical trait table is built across all imported interfaces before implementations are installed, so a default and its implementation may live in different modules.
- Installing a second visible trait method for the same concrete target/member reports `E3013` instead of overwriting the first scheme.
- The caller collects local declarations only after this outer environment exists.

## Linkage

- **Requires:** [[Type Interface]], [[Type Env]], [[Type Formation]], [[Type Check Method]], [[Type Value]], [[Syntax Tree]].
- **Consumed by:** [[Type Check]].

## Algorithm

Collect each interface's exported shapes and private nominal shells under its own module identity, overlay consumer-visible canonical type names, build the imported set's canonical trait table, publish complete body-free schemes and methods under canonical keys, then bind the consumer's selected or qualified value aliases.

## Negative Logic (Prohibited Paths)

- No dependency traversal, filesystem access, body checking, coherence checking, import diagnostics, private declarations, basename method keys, or runtime linking.

## Edge Cases

- Two interfaces may both export `User` and `Show`; interface-local formation prevents the later basename from rewriting the earlier implementation head.
- Two modules may export aliases with the same basename over distinct private nominal types; each consumer spelling expands to its own canonical hidden identity.
- Importing a type without its trait installs the shape but no implementation methods.
- An imported trait default is available from metadata even though its function body is absent.
- A foreign trait default is available when the trait interface and the local-target implementation interface are both loaded.
- Two imported, in-scope traits implementing the same member for one target diagnose ambiguity rather than depending on interface order.
- An imported foreign function is formed against the declaring interface's canonical handle shells and retains the `foreign` unsafe capability when published under qualified or selected spelling.

## Depth

DEPTH 0.64 (MEDIUM). The module isolates canonical interface installation and keeps the main checking walk below its source-size boundary.

## Grill Log

- **Q:** Put this logic in the program loader? **A:** No. _Rationale:_ the loader owns files and graphs; installing checker schemes is a type-phase concern. _Rejected:_ checker mutation from [[Compiler Program]].
- **Q:** Merge imported declarations into the local declaration list? **A:** No. _Rationale:_ that would reassign ownership and rerun coherence. _Rejected:_ a synthetic combined module.
- **Q:** Resolve method keys from the final merged basename map? **A:** No; temporarily overlay the interface's own local names while forming it. _Rationale:_ otherwise two modules exporting the same basename overwrite each other's heads. _Rejected:_ insertion-order identity.

## Referenced by

[[Type Check]] · [[src/Pudu/Type/_MOC]]
