---
type: module
path: "@root/src/Pudu/Type/Check.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.85
depth_status: DEEP
coupling: 6.0
interface_stability: 0.8
tags: [module, deep]
aliases: [Type Check]
---

# Type Check

## Purpose

Check every declaration, statement, and expression in a module against the types its declarations promise, inferring what the language allows to be left unwritten.

## Interface

### Signatures

```haskell
checkModule :: Module -> ([((Int, Int), Type)], [Diagnostic])
checkModuleWith :: ImportTypes -> Module -> ([((Int, Int), Type)], [Diagnostic])
```

### Governance

- Module bindings apply the same empty-Set boundary check as local statements after annotation
  unification, so `const EMPTY: Set[Int] = #{}` succeeds and an untyped `const EMPTY = #{}` reports
  `E3037` rather than publishing an unresolved scheme.

- Checking pushes an expectation inward at an `if`, a `match`, an array literal, a block, and a record field, so branches of different types widen against what the context asked for rather than against each other. It engages only where the expectation actually contains a dynamic type, so ordinary inference is unchanged. A record field's declared type is an expectation for the same reason a binding's annotation is.

- A trait-qualified call is resolved against the type its receiver actually has, not against the trait's declaration. `Speak.label(&bot)` names the trait, but the method it runs is the one `Bot` implements, and only that one knows the concrete types — a generic trait leaves its parameters open in the declaration by design. This is the rule [[Evaluator]] already followed for the same call, so the two phases now agree rather than only appearing to. The receiver is checked once and its type reused, so the call is never walked twice.

- Explicit type arguments pin what inference cannot settle. They instantiate the scheme with the
  caller's types in place of fresh variables, and carry the **same obligations**, so writing one
  never skips a bound the inferred version would have proved.
- **Fewer arguments than parameters is admitted**, and the rest are inferred. A caller writes one
  because inference could not settle that one; making them write the others too would mean writing
  down what the compiler already knows, which is the opposite of why they wrote any. More than the
  parameter count is `E3028`.
- Only a **name** may carry them — bare or qualified, since a qualifier is written as a member
  access and the chain is flattened back into the dotted name it stands for. An arbitrary expression
  has already been instantiated by the time it is an expression, which is a real restriction and is
  reported rather than worked around.

- A function literal is checked exactly like a declaration's body: parameters bound, result unified
  with what the body produced. Sharing the path is what keeps a literal and a declaration from
  drifting into two dialects of the same thing.
- A literal is **not** generalised. Its type is fixed where it is written, so a literal used at two
  types is an error the reader can see rather than a silent second instantiation of something they
  wrote once. Generalisation belongs to a declaration, which has a name to attach it to.

- A match reads its subject through a borrow. A match does not consume what it inspects, and every
  generic helper that takes `&Option[T]` needs to pattern-match on it; refusing would leave no way
  to write one except by copying. Whether an arm may *bind* by value out of a borrowed subject is an
  ownership question, and it belongs to ownership checking rather than here, where the only
  available answer would be to refuse the match entirely.
- Exhaustiveness is still checked against the referent, so looking through a borrow relaxes nothing.

- A statement that discards the result of a built-in collection method reports `W3002`. Those
  methods answer with a new collection rather than changing the one they were given, so
  `items.push(value)` written as a statement does nothing at all — and does it silently. There is no
  reading of that line under which it is correct, which is why it is a diagnostic rather than a
  style preference.
- The check is deliberately narrow: the closed set of built-in methods whose semantics the compiler
  already knows, on a receiver the checker has confirmed is a collection. A general unused-result
  warning would need to know which functions are pure, which Pudu does not track, and guessing would
  either miss this case or bury it in noise.
- `length`, `get`, `indexOf`, and `contains` are excluded. Discarding an answer to a question is
  pointless, not wrong, and the compiler has nothing to tell a reader that the line does not already
  say.

- A function body is checked against the *same* signature the module was given for its name, not a
  freshly formed copy. Without this tie the two hold separate variables for every position the
  declaration did not annotate, and whatever the body proves never reaches the name a caller — or a
  reader asking what the function is — actually sees: `fn add(a, b) { a + b }` reported two
  unresolved variables rather than `Int -> Int`.
- The tie is a unification, not a replacement: the declared signature is still the one announced to
  the rest of the module, and a body contradicting it must still fail against it.
- Only a module-scope function is tied. A member's scheme is recorded under a qualified key, and
  the plain name may belong to an unrelated free function in the same module; tying a member's body
  to whatever that name holds would unify two signatures that were never meant to meet.

- Signatures are collected before any body is checked, so a function may call one declared later, exactly as resolution already promised for names.
- Inference is local and bidirectional, matching [[architecture/SEMANTICS]]'s inference boundary: an absent annotation on a synchronous private function becomes a fresh variable the body solves, and no caller is ever inspected to type a callee.
- An exported function must annotate its parameters and its return type. An exported signature is a compatibility boundary that callers read without the body, so `E3010` asks for the annotation rather than inferring one.
- Every async function also annotates its parameters and return type. `E3010` rejects an incomplete async signature because callers must form stable `Task[S, E]` channels before bodies are checked, including forward calls.
- Exported trait members and every implementation method obey the same complete-signature rule because their bodies are stripped from module interfaces. `E3010` is emitted in the defining module before an incomplete member could become consumer-dependent inference.
- A declared generic parameter is rigid inside its declaration and is instantiated with fresh variables at every use, which is what lets one generic function serve several types.
- A match is checked for coverage by [[Type Exhaust]] after its arms are typed, so a scrutinee whose type failed earns no second complaint.
- Trait implementations are checked once by [[Type Check Coherence]] after signatures and method bindings are collected. `E3014` rejects a module that owns neither the trait nor the target's expanded nominal declaration, while `E3015` rejects duplicate heads; body checking can continue to preserve useful independent diagnostics.
- `checkModuleWith` installs [[Type Interface]] imports as outer declared/name/method state, then collects and checks only the current module. Imported bodies and coherence are never re-run. `checkModule` delegates with empty imports.
- Imported concrete method keys remain marked while local signatures are installed, so an imported-plus-local provider collision reports `E3013` instead of silently granting precedence to the local declaration.
- Every construct's rule is the one [[grammar/pudu]] states: an `if` condition is `Bool`, its reachable branches unify, `match` arms unify with each other and their patterns with the scrutinee, `while` and `for` are unit while `loop` takes the type its `break` statements carry, and `return` is checked against the enclosing function's declared result.
- A user-defined value is iterable only when `begin` and `advance` form one coherent protocol:
  both receivers unify with the iterated type, `begin`'s result is `advance`'s input and next state,
  and `advance` returns `Option[(State, Item)]`. Instantiating both method schemes registers their
  implementation bounds, so `Range[Float64]` cannot evade its `Integer` requirement.
- Async calls normalize their surface result into `Task[S, E]`. `.await` is admitted only inside an async function, accepts only a task, yields `S`, and requires the enclosing surface result to carry a compatible `Result` failure when `E` is not `Never`.
- Integer expressions register deferred arbitrary-precision literal constraints. Closed semantic boundaries validate literals that their local context has already solved, but preserve unresolved result literals for an enclosing annotation or operator. Boundaries that require a concrete operand shape, such as coverage over a literal scrutinee and `.await`, force only the operand's creation range to settle. The function/module boundary settles the remainder. This defaults only genuinely context-free unsuffixed literals to `Int` without prematurely defaulting a sibling or nested result.
- A callee written as `Name.member` selects a method by the declaration that name identifies: the trait that declares it or the type that implements it. The receiver is then an ordinary first argument, so a `&Self` method takes a borrow.
- A member in callee position prefers a method over a field of the same name, so `value.name()` is a call and a field holding a function is reached by parenthesizing it.
- A member whose target is a module-name expression first probes the full qualified value key (for example `Alias.make`) before receiver dispatch. This preserves the parser's shared dot syntax without treating module exports as fields or methods.
- A record construction checks each field against its declaration and requires every declared field; an unknown field and a missing field are distinct diagnostics because they are distinct mistakes.
- `ErrorType` is poison: it unifies with everything, so one mistake produces one diagnostic instead of a cascade through every later use.
- The checker keeps its own name frames rather than reusing the resolver's symbol table. The duplication is deliberate and bounded; a shared resolved representation is the slice that removes it.

- **A name that introduces something carries the type it was given.** Only uses were recorded, so an editor asked about `text` in `let text = "hello"` had nothing to answer with and named the enclosing function instead. A reader points at the place a name is introduced at least as often as at a use of it, and the same holds for a parameter.

### Linkage

- **Requires:** [[Type Env]], [[Type Interface]], [[Type Formation]], [[Type Unify]], [[Type Check Rule]], [[Type Check Pattern]], [[Type Check Method]], [[Type Check Coherence]], [[Type Exhaust]], [[Syntax Tree]], [[grammar/pudu]], [[architecture/SEMANTICS]].
- **Consumed by:** [[Type Boundary]].

## Algorithm

Collect declared shapes and signatures, check trait implementation ownership and duplicate-head coherence over the complete declaration list, then walk each declaration: a function binds its parameters and checks its body against its result, a block checks statements and yields its trailing expression, and an expression is inferred and recorded against the span it occupies.

## Negative Logic (Prohibited Paths)

- No specialization, task scheduling, ownership or borrow analysis, general defaulting of unsolved variables, caller-dependent inference, dependency traversal, or imported-body checking. Integer-literal fit/default constraints are the single numeric exception required by the grammar.

## Edge Cases

- A pattern that names an unknown variant binds its sub-patterns at the error type, so the arm still checks without inventing a shape.
- A call with fewer arguments than parameters is accepted here because a parameter may declare a default; arity is only rejected when there are too many.
- `?` unwraps a `Result` and requires the enclosing function to return a `Result` carrying the same failure type; `E3011` reports the case where it does not. Conversion through `From` waits for trait resolution.
- `.await` reports `E3016` outside an async function and `E3017` for a non-task operand. A task failure uses `E3011` when the enclosing return cannot propagate it; a mismatched `Result` failure type remains ordinary `E3001`.
- A private async function with an omitted parameter or return annotation reports `E3010` at the omitted contract component; synchronous private inference remains admitted.
- A literal bound by context to a compiler-wired integer type must fit its signed/unsigned interval. `E3018` names the value and selected type once; a suffix-selected type that conflicts with context remains ordinary `E3001`.
- A trait member body treats `Self` as a rigid parameter (added to the rigid list alongside the member's own type params), so `formType` produces `RigidType "Self"` rather than `NominalType "Self"`. This routes `self.method()` calls through `rigidMethod` and the trait bound installed by `selfBoundAsBound`, letting a default body call other trait methods on `self`. An impl member does not add `Self` to rigid: `Self` is aliased to the target nominal type through `implAliases`, so method calls resolve through the nominal path.

## Depth

DEPTH 0.85 (DEEP). One entry point hides signature collection, scope construction, bidirectional inference, and the rules for every construct in the language.

## Grill Log

- **Q:** Let module inference retain an unresolved Set element? **A:** No. _Rationale:_ module
  bindings feed tooling and imported interfaces; exporting an unconstrained variable would make
  their type depend on later consumers. _Rejected:_ generalizing the empty Set at module scope.

- **Q:** Infer exported signatures too? **A:** No; require the annotation. _Rationale:_ an exported signature is what callers compile against, and inferring it would let an unrelated body edit break them silently. _Rejected:_ whole-program inference; inferring and then freezing the first inferred shape.
- **Q:** Infer a private async signature from its body? **A:** No; require the same complete parameter and return annotations with `E3010`. _Rationale:_ a forward caller must split a surface `Result[S, E]` into task channels before the body is visited, so delayed inference would make task typing declaration-order dependent. _Rejected:_ guessing `Task[T, Never]`; caller-driven inference; a second body-checking pass.
- **Q:** How are cascades avoided? **A:** A failed unification yields `ErrorType`, which unifies with everything afterwards. _Rationale:_ the diagnostic contract requires that later phases not repeat a defect an earlier one already explained, and the same logic applies within a phase. _Rejected:_ aborting at the first error; suppressing by counting.
- **Q:** Should the checker reuse the resolver's symbols? **A:** Not yet. _Rationale:_ mapping references by span is fragile without a shared resolved tree, and the honest fix is that shared tree rather than a lookup that silently mismatches. _Rejected:_ span-keyed symbol lookup; merging the two phases.
- **Q:** Should `.await` merely pass through the task type? **A:** No; it yields the success channel and propagates the failure channel through the enclosing async result. _Rationale:_ a task is a suspended computation, not its eventual value. _Rejected:_ pass-through typing; nested `Task[Result[S, E], Never]`.
- **Q:** Should imported implementations be appended to the local declarations? **A:** No; install their interface schemes and relationships separately. _Rationale:_ concatenation would make the consumer appear to own dependency impls and re-run `E3014`/`E3015`. _Rejected:_ a synthetic combined module.
- **Q:** Infer an omitted method annotation again in each consumer? **A:** No; require a complete interface signature with `E3010`. _Rationale:_ a body-free cycle has no stable evidence from which to reconstruct inference, so fresh consumer variables would change the public contract by context. _Rejected:_ contextual reconstruction; carrying dependency bodies into the consumer checker.
- **Q:** Default integer literals before checking their context? **A:** No; validate solved constraints after annotations, arguments, operators, and branches unify, but leave an unresolved branch/result constraint for its enclosing context. Force a default only when a rule needs a concrete shape or at the body boundary. _Rationale:_ eager global defaulting recreates the issue where every width except `Int` is unusable, while creation-range settlement lets non-task `.await` name `Int` without stealing the contextual type of an `if` or `match` result. _Rejected:_ eager defaulting; defaulting every literal at a nested expression boundary; implicit narrowing from `Int`.

## Variants

- Runtime linking, scheduling, cancellation, and specialization join later slices; each extends the rules rather than reshaping the walk.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Boundary]] · [[Type Env]] · [[Type Unify]] · [[Type Check Coherence]] · [[architecture/SEMANTICS]]
