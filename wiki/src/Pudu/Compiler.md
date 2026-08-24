---
type: module
path: "@root/src/Pudu/Compiler.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.32
depth_status: SHALLOW
coupling: 2.0
interface_stability: 1.0
tags: [module, shallow]
aliases: [Compiler Pipeline]
---

# Compiler Pipeline

> `{-| @Program.Compiler.Module — orchestrates explicit compiler phases -}`

## Purpose

Provide the public phase orchestration entry point. In the first slice it lexes and parses [[Source Text]], combines ordered [[Diagnostic]] values, and withholds syntax when blocking errors exist. It will deepen as semantic/runtime/backend products are added.

## Interface

### Signatures

```haskell
data FrontendResult = FrontendResult
  { frontendTokens :: ![Token]
  , frontendModule :: !(Maybe Module)
  , frontendDiagnostics :: ![Diagnostic]
  }
  deriving stock (Eq, Show)

runFrontend :: Source -> FrontendResult

data CompileResult = CompileResult
  { compileTokens :: ![Token]
  , compileModule :: !(Maybe Module)
  , compileResolution :: !(Maybe Resolution)
  , compileTypes :: !(Maybe TypeInfo)
  , compileDiagnostics :: ![Diagnostic]
  }
  deriving stock (Eq, Show)

runCompile :: Source -> CompileResult

data CompileContext = CompileContext
  { contextExports :: !ExportIndex
  , contextTypes :: !(Map ModuleName TypeInterface)
  , contextStrictImports :: !Bool
  }
emptyCompileContext :: CompileContext
compileFrontendWith :: CompileContext -> FrontendResult -> CompileResult
runCompileWith :: CompileContext -> Source -> CompileResult
```

### Governance

- A module-scope `const` is evaluated at compile time, after typing and only when typing succeeded. [[architecture/SEMANTICS]] makes such a constant a compile-time value, so its initializer's failure is a compile diagnostic produced by the same bounded evaluator that runs the program.

- Phase order is fixed: lex, parse, expand macros, resolve names, check types, then evaluate module constants.
- Each phase runs only on what the previous one admitted — resolution on a parsed module, typing on a resolved one — so a syntax error never earns a second explanation from a later phase, matching the earliest-phase rule in [[architecture/SEMANTICS]].
- Parser still runs after lexical errors when a token stream exists, allowing useful independent diagnostics.
- The module result becomes `Nothing` when any error-severity diagnostic exists; raw parser result is not exposed as compilable.
- Diagnostics are combined and sorted once at the boundary.
- `runCompile` remains the isolated-source convenience API and delegates through `emptyCompileContext`, whose opaque-import mode preserves isolated tools and interactive buffers without a loaded program. [[Compiler Program]] parses each source once and calls `compileFrontendWith` with authoritative semantic and type interfaces.
- A compile context contains pure interfaces only. Filesystem discovery and IO errors never enter this module.

### Linkage

- **Requires:** [[Source]], [[Lexer]], [[Parser]], [[Name Resolution]], [[Semantic Interface]], [[Type Boundary]], [[Type Interface]], [[Token]], [[Syntax]], [[Diagnostic Model]].
- **Consumed by:** [[Compiler Program]], CLI, tests, and later compilation/evaluation entry points.

## Algorithm

1. `runFrontend` lexes/parses once and gates its module.
2. `compileFrontendWith` resolves against the semantic export index when the context is authoritative, or retains the isolated opaque-import behavior otherwise.
3. If resolution admits the module, form its imported type context and check types.
4. Stable-sort diagnostics, preserve phase products, and hide an invalid compilable module.

## Negative Logic (Prohibited Paths)

- No phase implementation logic in orchestration.
- No short-circuit after lexical diagnostics unless the lexer cannot produce its guaranteed stream.
- No printing, filesystem access, exit codes, or exception handling.
- No marking warnings as errors here.
- No dependency traversal, source-root inference, or interface construction; [[Compiler Program]] owns those policies.

## Edge Cases

- Empty source yields tokens plus diagnostics and no module.
- A recovered parser module remains hidden when diagnostics include errors.
- Warnings alone retain the module.

## Depth

DEPTH 0.32 (SHALLOW by current scope). This is intentional temporary orchestration, not a speculative abstraction. Its interface becomes valuable as it hides semantic configuration, caches, targets, and products in later slices. Deletion now would only move a few calls.

## Grill Log

- **Q:** Should a shallow orchestrator exist? **A:** Yes as the stable public composition point, but do not add service abstractions around it. _Rationale:_ later phases need one boundary and tools must not orchestrate independently. _Rejected:_ every caller directly chaining phases; framework-style pipeline objects.
- **Q:** Parse after lexical errors? **A:** Yes, because invalid tokens preserve progress. _Rationale:_ multiple actionable diagnostics improve tooling. _Rejected:_ fail-fast on first phase.
- **Q:** Return recovered AST with errors? **A:** Keep it internal; public compilable module is `Nothing`, while future tooling API may expose an explicitly recovered tree. _Rationale:_ prevent accidental compilation of poison nodes. _Rejected:_ treating recovery AST as valid.
- **Q:** Should program compilation re-run the frontend after graph discovery? **A:** No; pass the saved `FrontendResult` into `compileFrontendWith`. _Rationale:_ a module is parsed once per program compile and phase provenance stays stable. _Rejected:_ calling `runCompile` again for every loaded source.

## Variants

- Split tooling analysis and build pipelines once type checking exists, sharing explicit phase products rather than boolean flags.

## Referenced by

[[src/Pudu/_MOC]] · [[architecture/LANGUAGE]] · [[architecture/OVERVIEW]] · [[Tooling]]
