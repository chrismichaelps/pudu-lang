---
type: module
path: "@root/src/Pudu/Repl/Session.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.7
depth_status: MEDIUM
coupling: 5.0
interface_stability: 0.9
tags: [module, medium]
aliases: [Repl Session]
---

# Repl Session

## Purpose

Hold what an interactive session remembers, place each submission where the grammar allows it, and compile and evaluate the result.

## Interface

### Signatures

```haskell
data Session = Session
  { sessionImports :: ![Text]
  , sessionDeclarations :: ![Text]
  , sessionStatements :: ![Text]
  , sessionLoaded :: !(Maybe LoadedModule)
  , sessionContext :: !CompileContext
  }
data EntryKind = ImportEntry | DeclarationEntry | StatementEntry | ExpressionEntry
data EntryResult
emptySession :: Session
classifyEntry :: [Token] -> EntryKind
submitEntry :: Session -> Text -> IO EntryResult
inspectSession :: Session -> IO (Maybe Resolution, [Diagnostic])
loadModule :: FilePath -> Text -> IO (Session -> Session, [Diagnostic], Maybe Resolution)
contextSummary :: Session -> [Text]
sessionExports :: Resolution -> [Text]
```

### Governance

- A loaded program's dependencies are kept with the session and linked into every entry's
  evaluation, so a call into an imported module works at the prompt exactly as it does in the
  program that was loaded.

- Entries are kept as source text and recompiled together. That is what lets a later declaration change how an earlier one resolves, and it keeps the session's meaning identical to the meaning of the equivalent file.
- A submission is classified by its leading token: `import` and the declaration keywords go to module scope, `let`, `var`, and the jump and loop keywords are statements, and everything else is an expression.
- The compiled buffer is a complete module: the session's imports, then its declarations, then one synthetic function holding every statement entered so far. Statements and expressions are placed inside that function.
- The session advances only when an entry is accepted, so a failed entry can never corrupt a context that already worked.
- An expression is compiled and evaluated but never remembered: it produces no binding, and replaying it would repeat work without adding context.
- Only an expression yields a value to show. A declaration or binding is still evaluated as part of the buffer so its runtime failure surfaces, but it prints nothing when it succeeds.
- Loading delegates dependency discovery and checking to [[Compiler Program]], retains its pure `CompileContext`, then splits the admitted root text after its last import so session entries remain grammatically placed. Every later submission and inspection uses that context. Loading replaces the prior session entirely: nothing typed against the previous context survives a load it cannot explain.
- An expression entry also reports its static type, taken as the widest expression the checker typed inside the entry's own region of the buffer.
- `inspectSession` compiles the session exactly as it stands, so inspecting a session cannot alter it.

### Linkage

- **Requires:** [[Compiler Pipeline]], [[Compiler Program]], [[Evaluator]], [[Lexer Facade]], [[Token]], [[Syntax Tree]], [[Name Resolution]], [[Source]].
- **Consumed by:** [[Pudu REPL]].

## Algorithm

Lex the submission to classify it, assemble the buffer with the submission in its grammatical position, compile and evaluate, and report the buffer, the line the submission starts on, its diagnostics, and its value.

## Negative Logic (Prohibited Paths)

- No terminal, printing, persistence, independent dependency search, or grammar of its own. File/dependency IO is delegated to [[Compiler Program]].

## Edge Cases

- The first entry of an empty session compiles a module whose only content is the synthetic function.
- Re-running accumulated statements on every entry is deterministic because evaluation has no side effects; the slice that introduces them will have to revisit this.
- A loaded module's own header and imports are preserved exactly, so its diagnostics keep pointing at real lines.
- Iteration constructs (`while`, `loop`/`break`, `for`, `continue`) are statements when entered alone, so a loop that mutates a binding must be submitted as separate entries: the `var` binding, the loop body, then the result expression. The session replays accumulated statements on each compile, so a loop entered after its accumulator is visible in the synthetic function where the loop runs.

## Depth

DEPTH 0.70 (MEDIUM). It hides classification, buffer assembly, line mapping, acceptance, and evaluation behind one submission call.

## Grill Log

- **Q:** Replay the whole buffer or keep incremental state? **A:** Replay. _Rationale:_ a session then behaves exactly like the file it is equivalent to, and no separate incremental semantics can drift from the compiler's. _Rejected:_ caching resolved declarations; mutating an environment in place.
- **Q:** Should an expression be remembered? **A:** No. _Rationale:_ it binds nothing, and replaying it would re-run work with no effect on later entries. _Rejected:_ an `it` binding before there is a type to give it.
- **Q:** What happens to entries when a file is loaded? **A:** They are cleared. _Rationale:_ they were checked against a context that no longer exists, and silently reinterpreting them against a new file would be a different program. _Rejected:_ keeping bindings across a load.
- **Q:** Should `:load` compile only the named text and leave imports opaque? **A:** No; it uses the same program compiler as file checking. _Rationale:_ interactive and batch typing must agree, and the REPL is the feature gate. _Rejected:_ a REPL-only module lookup heuristic.

## Referenced by

[[src/Pudu/Repl/_MOC]] · [[Pudu REPL]] · [[Compiler Pipeline]] · [[Evaluator]]
