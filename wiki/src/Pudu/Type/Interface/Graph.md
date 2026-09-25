---
type: module
path: "@root/src/Pudu/Type/Interface/Graph.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.78
depth_status: DEEP
coupling: 5.0
interface_stability: 0.7
tags: [module, deep, performance]
aliases: [Type Interface Graph]
---

# Type Interface Graph

## Purpose

Prepare everything about a module graph's [[Type Interface]]s that does not depend on which module
is being checked — once per graph — and project each consumer's view of it as a small overlay.

## Interface

```haskell
data InterfaceGraph            -- abstract; Eq/Show by its interfaces
prepareInterfaces :: Map ModuleName TypeInterface -> InterfaceGraph
emptyInterfaceGraph :: InterfaceGraph
graphInterfaces :: InterfaceGraph -> Map ModuleName TypeInterface
graphOrder :: InterfaceGraph -> [ModuleName]
graphDeclared :: InterfaceGraph -> DeclaredTypes
graphInstalled :: InterfaceGraph -> InstalledNames

data ImportTypes = ImportTypes
  { importedInterfaces :: ![TypeInterface]   -- every interface but the consumer's, name order
  , importedNames :: !(Map Text NominalId)
  , importedValues :: !(Map Text Text)
  , importedTraits :: !(Set NominalId)
  , importedQualifiers :: !(Set Text)
  , importedModules :: !(Set ModuleName)
  , importedGraph :: !InterfaceGraph
  , importedConsumer :: !(Maybe ModuleName)
  }
importsFor :: InterfaceGraph -> Module -> ImportTypes
consumerIdentities, consumerTraits, consumerDefaults, consumerNames, contributesTo
```

## Governance

- **Prepared once per graph:** dependency order, exported identities, each interface's formation
  names, reverse import edges, the program's trait table and defaults, the collected declarations of
  every interface, the installed consumer-independent names, and the traits each interface
  implements. [[Compiler Program]] prepares one graph per compile; every module checks against it.
- **Collected declarations include the consumer's own interface.** The consumer collects its own
  declarations again on top, replacing each interface record under the same key, so inclusion is
  unobservable while exclusion would make the collection consumer-dependent.
- **Installed names** (the language's constructors, then each interface's constructors, trait
  members, and foreign functions, in module-name order) are a persistent map a consumer starts from
  and pays only for what it adds. The next free type variable travels with them.
- **Consumer overlays stay exact:** identities, trait table, and defaults exclude the consumer's own
  interface; an interface that imports the consumer (only inside a cycle) forms its names without
  the consumer's, as when each consumer prepared its own view.
- **An interface contributes to a consumer only** when the consumer imports it, it imports the
  consumer, or it implements a trait the consumer can see; the rest are passed over unread.
- Diagnostics raised while forming another module's declarations belong to that module and are
  reported once, when it is checked.
- Prepared facts are lazy, so a graph that fails before typing never forms them, and are discarded
  with the compile, so independent invocations never share state.

## Linkage

- **Requires:** [[Type Interface]], [[Type Env]], [[Type Formation]], [[Type Check Install]],
  [[Type Check Prelude]], [[Syntax Tree]], [[Syntax Name]], [[Type Value]].
- **Consumed by:** [[Compiler]], [[Compiler Program]], [[Type Check]], [[Type Check Import]],
  [[Type Boundary]].

## Algorithm

Order interfaces depth-first in module-name order so each follows what it imports. Compute each
interface's names from its own declarations and the exported identities of its imports. Fold
`collectDeclaredFrom` over the ordered interfaces once. Install builtins and every interface's
shared declarations in one checker run and snapshot the frame, restrictions, and next variable.
Form each implementation's trait head once. For a consumer, project its import pieces (left-biased
in import order), and derive exclusion overlays on demand.

## Negative Logic (Prohibited Paths)

- No per-consumer dependency search, trait-table union, default union, or interface collection.
- No sharing of unification state or unresolved checker variables across consumers.
- No persistence across invocations; no filesystem access.

## Edge Cases

- A cycle whose records name each other's types collects canonical identities on both sides.
- A dependency's formation mistake is reported once, not once per importer.
- Two modules sharing a bare constructor name resolve by module-name order, as before.

## Measurement

Optimized build, same host. `bench/graph.mjs` sparse graphs (best of three):

| Modules | Before | After |
|---:|---:|---:|
| 25 | 73.5ms, 84.0MB | 46.3ms, 28.7MB |
| 50 | 182.6ms, 253.6MB | 62.0ms, 56.7MB |
| 100 | 548.0ms, 871.5MB | 97.0ms, 113.9MB |
| 200 | 2917.8ms, 3281.4MB | 196.2ms, 231.3MB |

Allocation now doubles with the module count (x2.0 per doubling, from x3.0–x3.8).

## Grill Log

- **Q:** Share raw checker state across consumers? **A:** No; share only closed products — formed
  declarations and a snapshot of installed schemes whose next-variable counter is carried forward.
  _Rejected:_ sharing substitutions or live checker states.
- **Q:** Exclude the consumer from the shared collection? **A:** No; its local collection replaces
  every key it contributes. _Rejected:_ per-consumer suffix folds, which keep the quadratic cost.
- **Q:** Restrict implementations to direct imports to save work? **A:** No; global implementation
  discovery is required. The skip is exact: an interface implementing no visible trait installs
  nothing. _Rejected:_ import-scoped implementation tables.
- **Q:** Where does installation code live? **A:** [[Type Check Install]], below both this module
  and [[Type Check Import]], so preparation and consumers share one definition without a cycle.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Interface]] · [[Type Check Import]] · [[Type Check Install]] ·
[[Compiler Program]] · [[2026-09-21-interface-graph]]
