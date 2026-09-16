---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Repl/Session.hs"
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
  , sessionDependencies :: ![(Text, Module)]
  , sessionRetainedTypes :: !(Maybe TypeInfo)
  }
data EntryKind = ImportEntry | DeclarationEntry | StatementEntry | ExpressionEntry
data EntryResult
emptySession :: Session
classifyEntry :: [Token] -> EntryKind
invalidEntryStart :: [Token] -> Maybe Diagnostic
submitEntry :: Session -> Text -> IO EntryResult
submitEntryInContext :: EvaluationContext -> (Session -> IO ()) -> Session -> Text -> IO EntryResult
inspectEntryType :: Session -> Text -> IO (Source, Int, [Diagnostic], Maybe Type)
typeOfEntry :: Session -> Text -> IO (Maybe Type)
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
- A session that has imported anything is compiled as a **program**, not as a lone module: its imports are ordinary imports and must reach the same files on disk a compiled program's would. Before that, the session resolved an import loosely enough to type-check and then had nothing to link, so `Std.Math.factorial` was a name the checker knew and the evaluator did not, and a misspelt module produced no diagnostic at all.
- A session with no imports keeps compiling against its own context, which is what `:load` establishes and what every plain expression needs. The program path costs a filesystem walk, so it is taken only when there is something to walk for.
- A submission is classified by its leading token: `import` and the declaration keywords go to module scope, `let`, `var`, and the jump and loop keywords are statements, and top-level assignments (`=`) at bracket depth 0 are statements; everything else is an expression.
- A loop's `@label` is skipped before that decision is made. `@outer for ...` is the same statement as `for ...`, and classifying it as an expression would evaluate it where its assignments could not reach the session's own bindings.
- Top-level assignments (`target = expr`) are statement entries: because assignments produce `()` and mutate a place, classifying them as statements commits them to `sessionStatements` so that variable mutations persist across subsequent evaluations.
- `loop` stays a statement keyword even though it now has a value, so an ordinary loop at the prompt does not print `()`. Bind it — `let found = loop { ... break value }` — to see what it produced.
- The compiled buffer is a complete module: the session's imports, then its declarations, then one synthetic function holding every statement entered so far. Statements and expressions are placed inside that function.
- The session advances only when an entry is accepted, so a failed entry can never corrupt a context that already worked.
- An expression is compiled and evaluated but never remembered: it produces no binding, and replaying it would repeat work without adding context.
- Only an expression yields a value to show. A declaration or binding is still evaluated as part of the buffer so its runtime failure surfaces, but it prints nothing when it succeeds.
- Loading delegates dependency discovery and checking to [[Compiler Program]], retains its pure `CompileContext`, then splits the admitted root text after its last import so session entries remain grammatically placed. Every later submission and inspection uses that context. Loading replaces the prior session entirely: nothing typed against the previous context survives a load it cannot explain.
- An expression entry also reports its static type, taken as the widest expression the checker typed inside the entry's own region of the buffer.
- `inspectEntryType` assembles and compiles the same buffer as a submission but
  stops before evaluation. It returns the real assembled source, the entry's
  first line, compiler diagnostics, and the inferred expression type so every
  inspection consumer shares source mapping and typing behavior.
- Completion uses `typeOfEntry`, the narrow view of that probe: compiler errors
  and entries without an expression type both become `Nothing` because no
  completion list is safer than names that do not apply.
- `inspectSession`, `inspectContext`, and `inspectDocs` compile the session through
  the program compiler whenever imports are present, so inspecting documentation or
  context in an imported session resolves external module symbols identically to submission.

- **A function written as a value is an expression; the name is what makes one a declaration.** `fn double(n: Int)` declares and `fn(n: Int)` is a literal, and the same holds after `async`, which additionally opens a scope — `async with scope { .. }` is an expression however it ends. Classified as declarations, all three were read as declarations missing their names and answered `E1001: expected identifier`, for entries that name nothing because they are not naming anything.

- **Prompt submissions are validated against orphaned prefix operators before candidate buffer assembly.**
  While Pudu grammar allows binary operators without prefix forms (`<<`, `+`, `*`, `&&`, etc.) and postfix symbols (`.`, `?`) to continue across line breaks inside a file, each submission entered at the prompt is an atomic syntactic unit. If a submission begins with an orphaned operator or invalid prefix, it is immediately rejected with `E1040` (or `E1041` for reserved keywords) at `<interactive>:1:1` without assembling or compiling against prior statements. This guarantees prompt entries cannot accidentally fuse onto previous statement lines in `sessionStatements` or mutate session state.

- **The assembled buffer is a list of line groups joined once, so no group may carry its own trailing newline.** The loaded file's text arrives with the one every file ends with; left there it became a second, and the buffer held a blank line that counting the groups' lines did not. Every offset after it was short by one, which moved the window each question about a position searches — `:type` reported the runtime shape of whatever the misplaced window landed on, for the whole session, as soon as any file was loaded. Nothing about the text was wrong, which is why the buffer still compiled and ran correctly.

### Linkage

- **Requires:** [[Compiler Pipeline]], [[Compiler Program]], [[Evaluator]], [[Lexer Facade]], [[Token]], [[Syntax Tree]], [[Name Resolution]], [[Source]], [[Parser Expression Recovery]], [[Repl Evaluation]], [[Eval Context]].
- **Consumed by:** [[Pudu REPL]].

## Algorithm

Lex the submission to classify it (module declarations, statements including variable assignments, or expressions)
and assemble the buffer with the submission in its grammatical position. Inspection compiles that buffer and returns.
Ordinary submission continues into evaluation, then reports the buffer, the line the submission starts on, its diagnostics,
and its value.

## Negative Logic (Prohibited Paths)

- No terminal, printing, persistence, independent dependency search, or grammar of its own. File/dependency IO is delegated to [[Compiler Program]].
- A type probe never calls the evaluator, even when the assembled buffer
  contains earlier statements or the inspected expression would run cleanly.

## Edge Cases

- The first entry of an empty session compiles a module whose only content is the synthetic function.
- Ordinary submission re-runs accumulated statements, including their effects,
  because the current evaluator rebuilds the complete session buffer. Static
  inspection is the strict exception: it compiles that buffer but never runs it.
- **Top-level declarations and statement bindings permit dynamic redefinition.**
  Submitting a declaration (`fn`, `type`, `trait`, `const`) or binding (`let`, `var`) with a name
  already present in the session replaces the previous entry in the candidate buffer.
  If the candidate compiles cleanly without errors, the new definition is committed.
  If compilation fails (e.g. syntax error or type mismatch), the candidate is rejected,
  diagnostics are presented, and the previous valid session state is preserved untouched.
- A loaded module's own header and imports are preserved exactly, so its diagnostics keep pointing at real lines.
- Iteration constructs (`while`, `loop`/`break`, `for`, `continue`) are statements when entered alone, so a loop that mutates a binding must be submitted as separate entries: the `var` binding, the loop body, then the result expression. The session replays accumulated statements on each compile, so a loop entered after its accumulator is visible in the synthetic function where the loop runs.
- A type probe may compile earlier statements to recover the same lexical
  context as submission, but it never runs those statements or the current
  expression.

## Depth

DEPTH 0.70 (MEDIUM). It hides classification, buffer assembly, line mapping, acceptance, and evaluation behind one submission call.

## Grill Log

- **Q:** Replay the whole buffer or keep incremental state? **A:** Replay. _Rationale:_ a session then behaves exactly like the file it is equivalent to, and no separate incremental semantics can drift from the compiler's. _Rejected:_ caching resolved declarations; mutating an environment in place.
- **Q:** Should an expression be remembered? **A:** No. _Rationale:_ it binds nothing, and replaying it would re-run work with no effect on later entries. _Rejected:_ an `it` binding before there is a type to give it.
- **Q:** Why classify top-level assignments as statements rather than expressions? **A:** In Pudu, assignments evaluate to `()` and mutate a place. Classifying them as expressions would cause them to be discarded after evaluation, losing subsequent variable mutations. Statements persist in order and replay on every submission. _Rationale:_ state mutation must persist across prompts. _Rejected:_ forcing all mutations into a single multiline block.
- **Q:** Why route `inspectDocs` and `inspectContext` through `compileBuffer`? **A:** Interactive sessions that import standard or external modules need program dependency analysis during inspection; direct compilation against empty local contexts failed to resolve imported modules. _Rationale:_ consistent dependency resolution between evaluation and static inspection. _Rejected:_ duplicating import resolution logic.
- **Q:** What happens to entries when a file is loaded? **A:** They are cleared. _Rationale:_ they were checked against a context that no longer exists, and silently reinterpreting them against a new file would be a different program. _Rejected:_ keeping bindings across a load.
- **Q:** Should `:load` compile only the named text and leave imports opaque? **A:** No; it uses the same program compiler as file checking. _Rationale:_ interactive and batch typing must agree, and the REPL is the feature gate. _Rejected:_ a REPL-only module lookup heuristic.
- **Q:** Should completion and `:type` have separate probing paths? **A:** No;
  both consume one static compile probe. _Rationale:_ source offsets,
  diagnostics, and inferred types must agree, while the narrower completion
  view may deliberately hide diagnostics. _Rejected:_ a second partial
  compiler path or dry-run evaluation.
- **Q:** Why allow dynamic redefinition of top-level declarations and bindings in the session buffer? **A:** Iterative development requires modifying functions and variables without manual session resets. _Rationale:_ replacing prior definitions in the candidate buffer allows clean re-compilation; if the new code has type or syntax errors, the candidate is rejected and the working state is preserved without corruption. _Rejected:_ forcing `:reset` on duplicate declarations.
- **Q:** Why validate leading entry tokens before candidate buffer assembly? **A:** Pudu admits line-leading operators across line breaks within files, but REPL submissions are atomic syntactic units. Without pre-validation, submitting an orphaned operator (e.g. `<< 100`) after an expression statement would cause the synthetic `__session()` function to glue the operator onto the prior statement, re-evaluating or mutating state instead of diagnosing the missing left operand. _Rationale:_ prompt entries must behave identically regardless of whether prior statements exist in the session. _Rejected:_ disabling line-leading operators in the language grammar.

## Referenced by

[[src/Pudu/Repl/_MOC]] · [[Pudu REPL]] · [[Repl Evaluation]] · [[Compiler Pipeline]] · [[Evaluator]] · [[2026-08-31-static-repl-inspection]]



## Interactive boundary completion

Redefinition identity is extracted from lexer tokens, retaining Unicode identifiers and ignoring comments without stripping string contents. Only a single-line simple let/var binding or one top-level named declaration is replaceable. Multiline binding groups are deliberately not selected for replacement. Destructuring and multi-statement submissions are retained as independent source groups. Failed lexing never selects an old entry for replacement. Entry extension performs tokenization in IO; the session still commits only accepted candidates.

Resolved Grill Log: lexer tokens own syntax identity; do not infer it from textual word splitting. Existing source and compiler diagnostics remain authoritative. No tests or reviews run.

Source mapping counts each assembled group separator, including empty groups and trailing newlines. An appended identical statement maps to its final occurrence rather than an earlier copy. Resolved Grill Log: diagnostic offsets follow actual assembled text.

## Inspection candidate sequencing

`inspectEntryType` binds the result of `extend` in IO before rendering or compiling
the candidate. Inspection shares the same token-based replacement path as submission.
Resolved Grill Log: the lexer-backed extension operation returns `IO Session`; no
consumer may pass that action where a concrete session is required. Inspection still
stops at compilation and never evaluates user code.

## Persistent submission contract

`submitEntryInContext` shares compilation and reporting with `submitEntry`, but
appends statement source instead of replacing earlier executed bindings. It retains
a TypeInfo snapshot and dependency syntax for compatibility checks. Declarations
and imports must be established before local statements; subsequent changes require
`:reset` or `:load`. Earlier inferred expression types must remain identical, and
changed dependency syntax is rejected before runtime entry. This conservative rule
may reject harmless inference changes; it does not silently reinterpret live values.

Only AST nodes fully contained in the new submission execute. Previous statement
source remains available for type and ownership checking. Expression entries are
retained in persistent sessions as statements after execution, preserving ownership
and control-flow history without replay. The ordinary one-shot API retains its
existing behavior. Resolved Grill Log: runtime state and accepted source are published
together through the context callback. Failed external effects cannot be undone.
