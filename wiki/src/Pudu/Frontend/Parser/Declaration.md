---
type: module
path: "@root/src/Pudu/Frontend/Parser/Declaration.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.74
depth_status: MEDIUM
coupling: 7.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Parser Declaration]
---

# Parser Declaration

## Purpose

Orchestrate the compilation unit: one module header, ordered imports, and module-scope declarations, owning `export` visibility and declaration-level recovery.

## Interface

### Signatures

```haskell
parseCompilationUnit :: Parser (Maybe Module)
```

### Governance

- The orchestrator owns composition only. Import, binding, function, block, expression, type, and name grammar stay in their own modules, which never import this one.
- Exactly one `module` header is required and must come first; its absence yields `Nothing` with one `E1001`, so no file without a header is ever presented as a module.
- `export` is consumed here and passed to the declaration modules, which is why neither [[Parser Binding]] nor [[Parser Function]] can invent public API.
- Imports precede declarations. A later `import` is still parsed and preserved, but reports `E1034` so ordering is enforced without discarding recovered syntax.
- Module scope admits `const` and `async`/`fn` declarations. `let` and `var` reach [[Parser Binding]]'s module entry point, which rejects them once, keeping module-load execution and global mutable state unrepresentable; the orchestrator then synchronizes past the rejected binding so its initializer produces no further module-scope diagnostics.
- Reserved declaration keywords — `type`, `enum`, `struct`, `trait`, `impl`, `macro`, `comptime` — report `E1039` and synchronize instead of being silently accepted or dropped.
- Any other token at module scope reports `E1038` and is consumed, so a stray delimiter cannot stall the declaration loop at a synchronization boundary.
- Declaration iteration requires token progress and stops on a latched budget; a hostile file reports one `E1099` rather than a diagnostic per declaration.

### Linkage

- **Requires:** [[Parser State]], [[Parser Name]], [[Parser Import]], [[Parser Binding]], [[Parser Function]], [[Parser Block]], [[Syntax Tree]], [[grammar/pudu]].
- **Consumed by:** [[Parser]].

## Algorithm

Require the `module` keyword and path, collect leading imports, then loop declarations until EOF: consume optional `export`, dispatch on the leading keyword to constant, function, reserved, or unexpected-token handling, and merge the header-to-last-construct span into the module node.

## Negative Logic (Prohibited Paths)

- No expression, block, parameter, or import syntax of its own; no filesystem or module-path resolution; no name, type, or visibility semantics; no silent acceptance of reserved declarations.

## Edge Cases

- A module with no imports and no declarations is valid; a missing header consumes nothing beyond the reported token and returns `Nothing`.
- An `import` after a declaration is preserved in `moduleImports` with one `E1034`, so tooling still sees the dependency.
- Recovery from an unsupported declaration never consumes a following valid declaration's keyword.

## Depth

DEPTH 0.74 (MEDIUM). It centralizes compilation-unit structure, visibility ownership, ordering, and module-scope recovery while delegating every construct grammar.

## Grill Log

- **Q:** Should the orchestrator own block parsing, as the earlier monolithic draft did? **A:** No; [[Parser Block]] owns it and resolves the recursion itself. _Rationale:_ the orchestrator would otherwise be imported by the modules it composes, recreating the cycle the partition was meant to remove. _Rejected:_ a single declaration file holding block, function, and import grammar.
- **Q:** Keep or drop a misplaced import? **A:** Keep it and report `E1034`. _Rationale:_ ordering is a style/resolution rule, and discarding the node would hide a real dependency from later phases. _Rejected:_ silent acceptance; parsing it as an invalid declaration.
- **Q:** What happens to a stray `}` at module scope? **A:** Report `E1038` and consume it. _Rationale:_ [[Parser State]]'s synchronization stops at `}` so blocks can recover, so module scope must consume it or the loop cannot progress. _Rejected:_ synchronizing without consuming, which stalls; skipping to EOF, which discards recoverable declarations.

## Variants

- Type, trait, impl, and macro declaration modules join the folder as separate partitions; this module gains only dispatch entries.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Parser]] · [[Parser State]] · [[Parser Import]] · [[Parser Binding]] · [[Parser Function]] · [[Parser Block]]
