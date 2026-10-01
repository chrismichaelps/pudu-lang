---
type: handoff
tags: [handoff, runtime, performance, plan]
---

# Compiled Evaluation — Plan A: compiled expressions over the current environment

**Goal:** run function bodies as closures compiled once per body, with every per-step decision the
tree walker makes (which construct, which operator, which literal kind, which path) taken at compile
time, behind a switch, and proven identical to the tree walker on every fixture.

**Architecture:** a new pure-ish compiler `Pudu.Eval.Compile` turns a `Located Expression` into a
`Code` (an `Evaluator Value` built once). Constructs it does not yet cover compile to the tree
walker's `evaluateHere` for that expression, so the language is always runnable. Bodies are
compiled on first call and cached in the run's environment by the body's span. `PUDU_EVAL=tree`
selects the tree walker; compiled is the default once the oracle passes.

**Plan B** (separate, after A lands): replace name-keyed frames with slot arrays, which changes
capture and lending, and is where the larger factor of [[Compiled Evaluation]] comes from. It reuses
this plan's oracle and benchmarks unchanged.

## Global Constraints

- The tree walker stays, unchanged in meaning; it is the oracle and runs compile-time evaluation.
- Values, builtins, effects, stores, and diagnostics are unchanged. A difference in value, output,
  or diagnostic between modes is a compiler bug.
- Source files stay below 500 lines; comments describe invariants, never history or issue numbers.
- No complexity notation in comments; no comparisons to other languages.
- Measure at -O2 only, minimum of five runs, with `bench/eval.sh`.

## Task 1: Benchmarks and the evaluation switch

**Files:** create `bench/eval/{Loop,Calls,Records,Maps,Arrays,MultiMap}.pudu`, `bench/eval.sh`;
modify `src/Pudu/Eval/Env.hs` (field `envCompiled :: !Bool`, accessor `compiledEnabled`),
`src/Pudu/Eval.hs` (`withRuntime` reads `PUDU_EVAL`).

- [x] Copy the six scratch benchmarks into `bench/eval/`, sizes fixed in the source.
- [x] `bench/eval.sh <binary>` prints, per benchmark, the minimum of five runs in each mode:
  `PUDU_EVAL=tree` and `PUDU_EVAL=compiled`.
- [x] Add `envCompiled` (default `False` in `emptyEnv`); `withRuntime` sets it to
  `lookupEnv "PUDU_EVAL" /= Just "tree"` only after Task 4 flips the default; until then it is
  `== Just "compiled"`.
- [x] Commit `perf(evaluator): add evaluation benchmarks and a mode switch`.

## Task 2: The oracle

**Files:** create `test/Pudu/Eval/CompiledSpec.hs`; register it in `test/Main.hs` and
`pudu-tests.cabal`.

- [x] For every `test-fixtures/stdlib/*.pudu` with a `main`, run `runEntryValue` with
  `PUDU_EVAL=tree` and with `PUDU_EVAL=compiled` (set with `setEnv`, restored after), and assert the
  rendered values and the diagnostic codes are equal. Report every differing fixture by name.
- [x] It passes trivially now (both modes are the tree walker); it must keep passing through every
  later task.
- [x] Commit `test(evaluator): run every fixture under both evaluators`.

## Task 3: The compiler and its cache

**Files:** create `src/Pudu/Eval/Compile.hs`; modify `src/Pudu/Eval/Env.hs` (field
`envCompiledBodies :: !(IORef (Map Span Code))`, created in `withRuntimeEnv`), `src/Pudu/Eval/Call.hs`
(`closureOutcome` runs the compiled body when `compiledEnabled`).

**Interfaces:** `type Code = Evaluator Value`;
`compileExpression :: (Located Expression -> Evaluator Value) -> Located Expression -> Evaluator Code`
(the first argument is the tree walker, passed in to avoid an import cycle);
`compiledBody :: Span -> Evaluator Code -> Evaluator Code` (cache read or compile and store).

Covered constructs, each compiled to exactly what `evaluateHere` does:

- integer literals with their kind looked up once at compile time; other literals as constants;
- a single-segment name (a read through `lookupName`, no path search);
- binary operators with the operator decoded once: `=` to a plain name through `updateExisting`;
  `&&`, `||`; integer and other arithmetic through `combine` with the operator text captured;
- `if`/`else`, `while`, blocks (frame rules from `blockIntroducesBindings`), `let`, `return`;
- calls whose callee is a single name, through the existing `evaluateCall`;
- everything else: the tree walker for that expression.

- [x] Write the compiler, one function per construct group, each a straight line.
- [x] Oracle passes in compiled mode; `bench/eval.sh` recorded in the handoff.
- [x] Commit `perf(evaluator): compile function bodies to closures behind PUDU_EVAL`.

## Task 4: Switch-over

- [x] Flip the default: compiled unless `PUDU_EVAL=tree`.
- [x] Full suite, gates, and the oracle pass; record final `bench/eval.sh` numbers.
- [x] Mirror pages for `Eval Compile` and changed modules; changelog; issue closed.
- [x] Commit `perf(evaluator): run compiled bodies by default`.

## Status

Plan A is complete (#426). Measured at -O2 with `bench/eval.sh`, tree walker against compiled:
loop 2.68 s / 1.44 s, records 2.15 s / 1.25 s, calls 0.56 s / 0.36 s, maps 1.01 s / 0.70 s,
arrays 1.33 s / 1.00 s, multimap 7.85 s / 5.71 s. Fixtures that drive a real device (`Launch*`)
are outside the oracle, since their answer is a device clock reading.

## Exact next action

Plan B: write its plan for slot frames — resolve each function's bindings to frame indices after
checking, and give calls and blocks mutable slot frames, keeping capture and lending behaviour as
the oracle checks it.

## Referenced by

[[handoffs/_MOC]] · [[Compiled Evaluation]]
