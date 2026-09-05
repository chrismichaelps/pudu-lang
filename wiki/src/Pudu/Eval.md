---
type: module
path: "@root/src/Pudu/Eval.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.86
depth_status: DEEP
coupling: 5.0
interface_stability: 0.8
tags: [module, deep]
aliases: [Evaluator]
---

# Evaluator

## Purpose

Execute a parsed and resolved module by walking its tree, so a program can be run and an interactive session can print values before a backend exists.

## Interface

### Signatures

```haskell
data EvalOutcome = EvalOutcome
  { outcomeValue :: !(Maybe Value)
  , outcomeDiagnostics :: ![Diagnostic]
  }
evaluateEntryPoint :: Text -> Module -> EvalOutcome
evaluateModule :: Module -> EvalOutcome
```

### Governance

- **A module's functions capture the module that declared them.** They load first, so a sibling is an ordinary name while loading, and are then rewritten to hold the environment the load produced. Without it every module shared one namespace: dependencies link onto a single stack, so the last one linked shadowed every earlier one *for everybody*, and a module's own private helper could be replaced by a later module's export of the same name.
- **An implementation is not lexical.** Methods live in their own table, outside the frame stack, because an implementation is a fact about a type and a trait that is true everywhere in a program once it exists anywhere in it — which is what the orphan rule is for. Keeping them out of the frames is what lets a library's adapter dispatch to a program's own type, linked long after the library was. The two namespaces have opposite scoping rules, so they are two namespaces.

- A value the evaluator cannot enumerate directly is asked whether it is a sequence: a type carrying `begin` and `advance` produces its items one at a time. The protocol passes state rather than mutating it, so an iterator is an ordinary value and two walks of the same one see the same items. A type with only one of the two methods is not a sequence, and saying so at the `for` keeps the failure out of the middle of a loop.

- A type argument is **not erased before the call that carries it**. Types have no run-time form,
  but the syntax the reader wrote is still in the tree, and `convertInteger` needs to know which type
  it was asked for. Reading it is not the evaluator knowing about types; it is the evaluator reading
  the call it was given.

- Evaluation runs over `IO`. A program reads a file, writes to its output, and asks its environment
  questions; running over `IO` is what lets it, rather than a second interpreter existing beside
  this one for the effectful half of the language.
- **Compile-time evaluation runs the same interpreter with effects denied.** A constant is folded
  while the compiler runs, and letting it read a file would make compilation depend on the world the
  compiler happened to be in, and would produce output nobody asked for. `E7009` reports the
  refusal, naming the boundary rather than the operation, because every operation behind it is
  refused for one reason.
- Every run allocates an isolated resource set and tears down only that set on every exit path.
  Concurrent evaluations in one host process therefore cannot close one another's foreign handles,
  files, sockets, or synchronization objects. Child tasks stop before foreign teardown, and each
  unreleased owned foreign handle runs its declared destructor exactly once.
- Every effect answers with `Result[T, Str]`. `exit` is the only one that does not, because a
  program that asked to stop has nothing left to decide.

- A function literal captures the environment it was written in; a declaration does not. A
  declaration is called in the environment it is called from, which is what lets a module's functions
  see each other and an imported module's frame stay reachable. A literal may be returned, stored,
  and called long after the block that gave its free names meaning has ended.
- A literal captures every frame in scope rather than only the names its body mentions. Capturing
  selectively would need the resolver's answer about free names, and the two would have to agree
  forever; capturing the environment means they cannot disagree.
- A member chain of plain identifiers is tried as one dotted name before it is read as a field
  access, so a module's function can be passed as a value. `Std.Char.toUpper` is one binding;
  `record.field.inner` is two reads, and is untouched because its base is bound.

- Text indices count Unicode scalars, not bytes, so `charAt` and `slice` agree with what a reader
  counting characters expects. It is the same choice indexing already makes.
- An index outside the text is `E7004`. A silent clamp turns a logic error into wrong output that
  looks correct.
- A slice is clamped at the **end** and refused at the **start**: a `to` beyond the text is the
  ordinary way to ask for "the rest", while a negative `from` is arithmetic that went wrong.

- A program's dependencies are linked before its entry point runs. Each is loaded into a frame of
  its own and republished under its dotted path, so `Std.List.sum` is a name in the environment
  rather than a member access on a value that does not exist.
- A dependency's frame **stays on the stack** rather than being popped. A function is a closure over
  the environment it is called in, not one captured when it was defined, so `gcd` calling its
  sibling `abs` needs `abs` to still be a plain name. Leaving it is safe: a dependency's frame is
  outside the importing module's, so the importer's declarations shadow it, and name resolution has
  already rejected any unqualified use of a name the importer did not import.
- A dependency's private declarations are published under the qualified path too. Visibility is
  resolution's decision and it has already been made; re-deciding it here would put one rule in two
  places and break a public function whose body calls a private helper.
- A dotted path resolves to the longest bound prefix. `Std.List.sum` is one binding while
  `point.x.y` is three reads, and preferring the longer match cannot shadow a local because a
  value's own name never contains a dot.

- A structured scope adopts every task started inside it. Awaiting a task joins it there; a child never awaited is joined when the scope exits, in the order the children started, so no task outlives the region that began it and a failure among them is selected by position rather than by a race. A control transfer out of a scope joins its children before continuing.

- Evaluation runs only on a module the earlier phases admitted. It re-checks nothing they proved, and it invents no value for syntax they rejected.
- A Set literal evaluates every member left to right, rejects the first unorderable resulting value
  with `E7008`, then constructs the existing key-ordered Set. Duplicate results collapse only after
  their expressions have run. Membership evaluates candidate then Set and performs one keyed lookup.
- `if let` evaluates its subject once and delegates the test to [[Eval Match]]. Successful bindings
  run the then block in one temporary frame; failure evaluates else or yields unit.
- Functions and variant constructors are installed before any constant is evaluated, so mutual recursion and forward references behave exactly as resolution promised. Constants then evaluate in declaration order, and one that reads a later constant is a runtime diagnostic rather than a silent default.
- `return`, `break`, and `continue` travel as an unwind that the owning construct catches: a call catches a return, a loop catches a break or a continue. This is what makes a `return` inside a nested block leave its function instead of becoming that block's value.
- A break and a continue carry the label they were written with. A loop catches one addressed to it — by name, or by being the innermost when no name was given — and lets every other one keep travelling outward, which is exactly how `break @outer` from a nested loop leaves the outer one rather than the nearest. A break also carries the value its loop will produce; a break naming none carries unit.
- Integers remain arbitrary precision until fixed-width runtime lowering arrives. Floats retain their admitted `Float32`/`Float64` precision and normalize narrow results through binary32, because a literal suffix provides the width without requiring typed-tree annotations. Integer `&+`, `+|`, and their siblings still compute exactly until fixed-width lowering. Division and remainder by zero are diagnosed where the rule is width-independent.
- Arguments bind left to right; a parameter with no argument evaluates its default in the environment the earlier parameters already extended, matching the declared evaluation order.
- Assignment writes the binding where it was declared rather than creating a new one in the innermost frame.
- Recursion and iteration are bounded. Exceeding either reports `E7002` rather than exhausting the host, which keeps an interactive session usable after a runaway program.
- Runtime failures are ordinary diagnostics: `E7001` shape and definedness, `E7002` limits, `E7003` arity, `E7004` domain errors such as division by zero and index range, `E7005` no matching arm – a defensive path once exhaustiveness checking runs, but still reported rather than crashing – `E7006` a jump outside a loop — now a defensive path, since [[Name Resolution]] rejects one as `E2016` before the program runs — `E7007` a panic from the prelude's `panic` builtin, which represents a violated invariant rather than a recoverable domain failure, `E7010` a decimal quotient with no terminating base-ten expansion, which is reported rather than rounded because rounding is the decimal analogue of a silent integer wrap.
- Calling an async closure evaluates supplied arguments and omitted defaults left to right, then returns a cold `TaskValue` without running the body. `.await` starts that prepared body; `Ok` yields its payload, `Err` propagates like `?`, and awaiting a non-task is defensive runtime `E7008`.

- **A type that writes `Sequence` is iterated by it, and a sum falls back to its payload only when nothing does.** [[Type Check Iteration]] decides the binder's type in exactly this order, and taking the payload first made the two disagree: a program with its own implementation type checked against the implementation and then ran against the payload, so a binder the checker called `Int` held a variant.
- **A value names the variant it is; an implementation is written for the type that declares it.** Every method lookup on a receiver therefore tries the variant's own name and then what that variant belongs to — a direct call, a trait-qualified call, and the sequence protocol all go through the same two names. Without the second, `impl Shaped for Round` was unreachable from a `Circle` and no trait method worked on any sum at all. The variant's own name is tried first, because a record type is its own owner and must not be looked past.

- **The compiler must terminate; a program need not.** A loop is bounded only while effects are refused, which is exactly when a `const` is being folded and a loop that never ends would be a build that never ends. A program the reader ran is bounded by the machine. A fixed step count applied to both is not a safety property — an input of any size needs more steps than any constant this module could pick, so the bound made every file unreadable rather than making anything safe.

### Linkage

- **Requires:** [[Eval Value]], [[Eval Env]], [[Eval Match]], [[Eval Operator]], [[Syntax Tree]], [[Diagnostic Model]].
- **Consumed by:** [[Pudu REPL]] and future tooling; the eventual backend replaces it for compiled execution.

## Algorithm

Install declarations, evaluate module constants, then evaluate the named entry point: statements run in order inside block frames, expressions evaluate left to right, and control transfers unwind to the construct that owns them.

## Negative Logic (Prohibited Paths)

- No type checking, coercion, or inference; no ownership, borrow, or drop behaviour; no scheduler or parallel execution; and no silent recovery from a runtime failure. Method dispatch follows the implementations already admitted by semantic checking, and effects use the explicit evaluator boundary described above.

## Edge Cases

- A control transfer that reaches the top has left every construct that could own it: a return yields its value, a stray break or continue yields unit rather than losing the run.
- Iteration handles built-in enumerable values directly and asks every other nominal value for the admitted `begin`/`advance` sequence protocol; a missing or malformed protocol says so instead of silently doing nothing.
- `?` yields the success value or returns the failure from the enclosing function unchanged, which is the elaboration [[architecture/SEMANTICS]] gives it.
- A member access finds a field first and a method of the value's type second; in callee position the method wins, matching how the same call is typed. A method call binds the receiver as the function's first parameter.
- A trait-qualified call derives its receiver owner through [[Eval Operator]]'s `nominalNameOf`, so implementations for wired-in scalars dispatch by exact kind (`UInt8`, not a generic integer label) as well as implementations for records and variants.
- The interpreter's task is cold and deterministic but not concurrently scheduled. Awaiting the same immutable task value again replays its pure body until the scheduler slice introduces task identity and at-most-once state; current Pudu has no task-observable IO, clock, or randomness.
- `evaluateEntryPoint` drives a task only when the named entry function itself is async. An ordinary entry that returns a task receives the opaque task unchanged, preserving cold calls at the host boundary.

## Depth

DEPTH 0.86 (DEEP). One entry point hides declaration installation, environment frames, control unwinding, operator semantics, pattern matching, and bounded execution.

## Grill Log

- **Q:** Why not keep a very large bound instead of removing it while running? **A:** Because any constant is wrong for some input. _Rationale:_ the bound exists to stop the compiler hanging, and nothing about running a program needs it; picking a bigger number only moves the size of file that fails. _Rejected:_ raising the limit; making it a flag, which asks every reader to know a number that should not exist.
- **Q:** Why does the evaluator need a variant-to-type map when the checker does not? **A:** Because a runtime value has lost its type. _Rationale:_ the checker holds `List` and looks up `List.begin` directly; the evaluator holds a `Cons` and nothing in the value says which sum it came from, so the declaration has to leave that behind at install time. _Rejected:_ tagging every value with its owning type, which costs every value for a lookup few need.
- **Q:** Should the evaluator wait for the type checker? **A:** No. _Rationale:_ an interactive session that cannot produce a value teaches nothing about the language, and every rule the evaluator applies here is one typing will later refine rather than contradict. _Rejected:_ a checking-only session; a stub evaluator returning placeholders.
- **Q:** How do `return`, `break`, and `continue` leave nested blocks? **A:** As unwinds through the evaluator's own result type. _Rationale:_ the first attempt made a block yield a control value, and a `return` inside an `if` became the `if`'s value — the tests caught it immediately. _Rejected:_ threading a flow value through every expression; host exceptions.
- **Q:** What width do fixed-width operators use? **A:** None yet; they compute exactly and are documented as awaiting typing. _Rationale:_ guessing 64 bits would produce wrapping the declared type never asked for, which is worse than exact arithmetic. _Rejected:_ assuming a default width; refusing to evaluate arithmetic at all.
- **Q:** Should a runaway loop hang the session? **A:** No; iteration and recursion are bounded and report `E7002`. _Rationale:_ an interactive tool must survive its user's mistakes. _Rejected:_ unbounded execution; a wall-clock timeout, which would make results irreproducible.
- **Q:** Execute an async body when it is called? **A:** No; prepare its argument bindings and return a cold task, then run the body at `.await`. _Rationale:_ this preserves the language's first observable async boundary before scheduling exists. _Rejected:_ eager calls with pass-through await; fake concurrent scheduling in the tree walker.
- **Q:** Implement membership by iterating the Set? **A:** No. _Rationale:_ [[Eval Keyed]] already
  owns the balanced-tree lookup and its equality; iteration would discard the data structure's
  complexity and duplicate comparison policy. _Rejected:_ `any` over rendered members.
- **Q:** Use process-global resource registries? **A:** No. _Rationale:_ teardown belongs to the run
  that acquired the resource, and global clearing races with other embedded runs. _Rejected:_ a
  global evaluation mutex, which would make independent programs block one another.
- **Q:** Leave foreign handles alive when evaluation returns or aborts? **A:** No. _Rationale:_ an
  owned result promises deterministic cleanup across every exit path. _Rejected:_ relying on process
  exit or requiring every branch to remember an explicit destructor call.

## Variants

- A compiled backend replaces this walker for release builds; the diagnostic codes and value shapes stay the contract tools depend on.

## Foreign cleanup reporting

After workers stop, foreign resources close before the final outcome is returned. The per-run
foreign cleanup journal is appended to `outcomeDiagnostics`; warnings do not discard a successful
value. Cleanup failures observed while a boundary aborts become related information on that
primary diagnostic. Exceptional host termination may have no outcome to carry diagnostics.

### Resolved Grill

- **Q:** Collect cleanup diagnostics before teardown? **A:** No; a destructor can fail during
  teardown itself. Close resources before draining the journal, retaining the bracket for exceptional exits.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Pudu REPL]] · [[Syntax Tree]] · [[Diagnostic Model]] · [[Semantics]]
