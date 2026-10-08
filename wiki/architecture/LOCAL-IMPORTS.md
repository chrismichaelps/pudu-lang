---
type: architecture
status: DESIGN
aliases: [Scoped Import Design]
tags: [imports, resolution, design]
---
# Scoped Import Design

Pudu block-local imports should place a dependency beside its use while preserving build-time discovery, checking and packaging. Proposed syntax reuses `import Std.Text`, `import Std.Text as Text` and `import Std.Text {toTitle}` inside lexical blocks. This syntax is not implemented or accepted yet.

A local import would activate after its complete declaration and end with its block. Subsequent closures and nested blocks would see it; earlier statements, signatures, enclosing and sibling scopes would not. All literal absolute module dependencies, including unreachable imports, would be discovered and checked at build time. Calls would use shared immutable prelinked exports without reading or initializing source modules. Bind an owner reference rather than copying its export table on every call; prepared execution may elide the declaration after resolving its members, with ordinary execution retaining the same meaning.

Complete delivery requires grammar/recovery, scoped resolution and typing, exhaustive tree persistence/traversal, privacy and effect enforcement, all dependency inventories, cycle/cache/constant invalidation, packaged execution, watched runs, graph layers, and editor visibility. Never flatten local imports into module scope. Runtime-computed paths and module values are separate features. The full regression matrix must cover each of those boundaries before accepting new syntax.

Repeating an outer import inside a block would create a block-local binding of the same prelinked module, retaining the ordinary shadow warning. Two declarations of the same alias in one block would retain E2001. Separate sibling functions could reuse an alias independently. Shadowing with another module would retain the same warning and resolve all members/types through the nearest binding. Leaving a block would restore the outer alias; dependency discovery would deduplicate canonical modules while preserving every import span. These cases belong to the scoped-import regression matrix.

## Resolved qualifier prerequisite (#470)

A whole-module qualifier names a namespace, not a runtime value. Current checking accepts `let tooling = Text` after importing Std.Text as Text, while execution fails with E7001. Fix this before expanding import placement.

[[Semantic Interface]] classifies authoritative qualifier bindings separately from selected exports. Both lexical namespaces remain declared, preserving duplicates and qualified value/type paths. Isolated resolution classifies syntactically known qualifiers but keeps selected items opaque. A loaded missing/invalid interface retains unclassified placeholders so the loader's E2014/E2015 remains primary.

[[Resolve Context]] records the introduced qualifier's SymbolId in invocation-owned [[Resolve State]]. Ordinary expression resolution refuses that exact identity with E2010, the qualifier span, and help to select an exported member. Selected exported functions, constants and constructors remain values. Ordinary local shadows have different identities. Qualified paths retain their existing resolution. Reflection's E2018 remains the sole refusal outside derives; inside a derive a bare module qualifier still has no runtime value.

## Resolved Grill Log

- **Q:** Discover modules while a function runs? **A:** No. Predictable dependencies, deployment and effect checking require build-time resolution. Locality changes lexical visibility only.
- **Q:** Support `let tooling = import ...` by accepting a namespace as a value? **A:** No. A module value needs its own type, privacy, identity and lifetime contract. Selecting an exported function already supplies an ordinary function value.
- **Q:** Identify qualifiers by spelling or remove their value-namespace binding? **A:** Neither. Track resolved symbol identity and preserve declaration conflicts, qualified access and normal shadows.
- **Q:** Diagnose a qualifier when its module failed discovery? **A:** Preserve the loader's earlier failure and opaque recovery placeholders. Do not add a cascade that hides the source problem.
- **Q:** Add E2010 beside reflection's refusal? **A:** No. Existing reflection refusal has priority outside derives; selected reflection exports retain the same restriction.

Qualified member lookup currently bypasses a nearer constant value shadow; #471 tracks that separate prerequisite. Scoped imports must honor the nearest value identity for expression members while retaining independent type lookup.

Independent semantic, implementation and vault-parity review is required for #470. Scoped syntax remains separate design work until its complete contract and implementation are reviewable.

## Referenced by

[[architecture/_MOC]] · [[Module Qualifier Delivery]] · [[Name Resolution]] · [[Semantic Interface]]
