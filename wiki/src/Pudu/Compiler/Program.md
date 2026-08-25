---
type: module
path: "@root/src/Pudu/Compiler/Program.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.78
depth_status: DEEP
coupling: 6.0
interface_stability: 0.75
tags: [module, deep]
aliases: [Compiler Program]
---

# Compiler Program

## Purpose

Turn one root `.pudu` path into a deterministic, checked module graph without letting filesystem policy leak into name resolution or typing.

## Interface

### Signatures

```haskell
data ProgramResult = ProgramResult
  { programRoot :: !(Maybe ModuleName)
  , programModules :: !(Map ModuleName CompileResult)
  , programSources :: ![Source]
  , programOrder :: ![ModuleName]
  , programDiagnostics :: ![Diagnostic]
  , programContext :: !CompileContext
  }

compileProgram :: FilePath -> IO ProgramResult
rootCompileResult :: ProgramResult -> Maybe CompileResult
```

### Governance

- `compileProgramSource` compiles a root that is already in memory, taking its source root rather than deriving one. The interactive session's buffer is not a file, but its imports still have to reach the modules a compiled program's would, and there is no path to derive the root from.

- A module is looked for in the roots [[Compiler Library]] names, in order: the program's own
  source root, then — for a `Std` module only — the standard library's. The first root that has the
  file wins, so a program can shadow a standard module by declaring it in its own tree.
- A missing `Std` module is reported with help that points at the library, because it is almost
  always a misspelling of a module that exists rather than a file the author forgot to write.

- The root source is parsed first. Its declared module name and file suffix determine the source root; `A.B` maps to `A/B.pudu` below that root.
- Imported module names are absolute. Each name maps to one canonical path and each canonical path is read at most once.
- Missing/unreadable imports become `E2014` at the importing path. An unreadable root also becomes `E2014`, against a retained empty source snapshot carrying the requested path. Host `IOException` values never escape the boundary.
- A dependency whose declared module name differs from the path requested for it reports `E2015` at its module header and contributes no interface.
- Dependency order is deterministic and published as `programOrder` for tooling/test evidence. `Data.Graph.stronglyConnComp` classifies cycles and orders SCCs; modules inside an SCC are ordered by canonical module name.
- Cycles are allowed for declaration signatures. Interface skeletons for an SCC are available before bodies in that SCC are checked; no module-scope runtime initialization is introduced.
- The graph compiles through [[Semantic Interface]] and [[Type Interface]]. It never concatenates ASTs or pretends dependency declarations belong to the root module.
- Diagnostics retain their original source identities and are stable-sorted once across the program.
- Sources are retained as source snapshots so CLI rendering quotes the snapshot that owns each diagnostic, including failures before a root module name exists; the admitted pure compile context is retained so a REPL load can check later entries against the same interfaces.
- `compileProgram` is the shared filesystem boundary for `pudu check` and [[Repl Session]] loading; the pure single-source [[Compiler Pipeline]] remains available for isolated tools and tests.

### Linkage

- **Requires:** [[Compiler Pipeline]], [[Semantic Interface]], [[Type Interface]], [[Parser]], [[Source]], [[Diagnostic Model]], [[Syntax Tree]], [[grammar/pudu]].
- **Consumed by:** [[Pudu CLI]], [[Repl Session]], focused graph tests, and later build/package tooling.

## Algorithm

Parse the root, derive its source root, then chase each import name to its canonical `.pudu` path while memoizing loaded frontends. Build graph nodes from parsed import lists, classify and order them with `stronglyConnComp`, construct export/interface skeletons for all parsed modules, and compile SCCs in dependency order. Aggregate every diagnostic by source/span/code/message and expose the root result separately from the graph map.

## Negative Logic (Prohibited Paths)

- No filesystem reads from resolution, type checking, evaluator dispatch, or interface lookup.
- No basename-only module/type identity, directory-wide scanning, wildcard discovery, current-working-directory fallback after the source root is known, or AST concatenation.
- No runtime linking claim: this slice loads dependency signatures and implementations for static checking, not executable dependency bodies.
- No swallowed IO exception and no error result that later phases treat as a valid module.

## Edge Cases

- A root filename may be supplied by path, but its suffix must still agree with its declared multi-segment module name before dependencies are followed.
- Diamond imports read and parse the shared dependency once.
- A self import is one cyclic SCC and does not recurse forever.
- A missing transitive dependency is reported at the transitive import, not at the root command line.
- An invalid dependency may produce frontend diagnostics, but it exports no interface and cannot cause follow-on type diagnostics in dependents.
- An unreadable root has no module identity, but still returns one `E2014` and its requested-path source snapshot; command-line checking therefore cannot report success for an I/O failure.

## Depth

DEPTH 0.78 (DEEP). One IO entry point hides source-root derivation, canonical path mapping, memoized dependency discovery, SCC ordering, phase gating, interface orchestration, and program-wide diagnostic ordering.

## Grill Log

- **Q:** Should the resolver open imported files? **A:** No; the program compiler loads sources and passes interfaces inward. _Rationale:_ lexical/name phases stay deterministic and testable over values, while filesystem failures have one owner. _Rejected:_ lazy IO during lookup; global module cache inside the resolver.
- **Q:** How is a module path chosen before manifests exist? **A:** Derive the source root by removing the declared module suffix from the root path, then map every absolute module name below it. _Rationale:_ this implements [[grammar/pudu]]'s manifest-relative invariant without inventing search paths. _Rejected:_ current-directory search; recursive directory scan; several candidate paths.
- **Q:** Why SCCs rather than rejecting every cycle? **A:** [[architecture/SEMANTICS]] admits cycles for signatures. _Rationale:_ interface skeletons break signature cycles without module-load execution. _Rejected:_ naive DFS order; unconditional cycle error; fixed-point body checking.
- **Q:** Should dependency ASTs be merged into the root? **A:** No. _Rationale:_ merging destroys module ownership, privacy, nominal identity, and diagnostic provenance. _Rejected:_ synthetic mega-module; textual inclusion.
- **Q:** Should runtime dependency execution be bundled into issue #29? **A:** No. _Rationale:_ static interface loading closes the reported `E3005`; runtime linking requires a separate value/module environment and conformance gates. _Rejected:_ silently installing dependency bodies into one evaluator frame.

## Variants

- A project manifest later supplies the source root and additional package roots without changing graph or interface semantics.
- Incremental builds may cache frontend/interface fingerprints behind the same deterministic result.

## Referenced by

[[src/Pudu/Compiler/_MOC]] · [[Compiler Pipeline]] · [[Pudu CLI]] · [[Repl Session]] · [[Type Interface]] · [[Semantic Interface]]
