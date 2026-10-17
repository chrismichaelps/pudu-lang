---
type: module
path: "@root/src/Pudu/Backend/Emit.hs"
fidelity: Active
domain: "[[Core IR]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, codegen]
aliases: [Backend Emit, C Emitter]
---

# Backend Emit

## Purpose and interface

Translate a [[Core IR]] module into one deterministic C11 translation unit:
the program's functions, the diagnostic site table its checked operations
point at, and the [[Backend Runtime]] parts that implement them. Emission
is a pure function of the core module, the program's sources, and the compiler
version, so the same program always produces the same bytes — that is what
makes the artifact cacheable, diffable, and testable as a golden.

```haskell
emitProgram :: Text -> [Source] -> CoreModule -> Text
```

## Algorithm and invariants

- Output order is fixed: a header comment naming the compiler version and the
  module, the runtime parts the module needs in their fixed order (each
  followed by a blank line), the site table, prototypes for every carried
  function, the per-callee call wrappers, the function definitions in
  declaration order, and the C `main`.
- Runtime selection is a walk over the core module (`runtimeNeeds`): every
  program carries the prelude, and only an Int entry carries the status clamp; a checked operation adds
  the site table, the colour decision, the refusal renderer, and its own
  helper; a call adds the same three plus the call-depth part; each printer
  adds itself. Selection is a pure function of the module, so unused helpers
  never enter the translation unit and the build stays warning-free.
- Locals emit as `int64_t pudu_v<id>` / `int pudu_v<id>`; temporaries as
  `int64_t pudu_t<n>` with a translation-unit counter; names are never derived from source names,
  so shadowing, unicode, and C keywords cannot collide or leak into
  identifiers. The source name appears once, in a comment on the declaration.
- Checked operations emit calls to runtime helpers with the index of their
  site: `pudu_add(a, b, &pudu_sites[3])`. `+ - * / %` and unary `-` each have
  their sites; `/` carries two (zero, overflow) and `%` one (zero), matching
  the interpreter's refusals exactly.
- A site is baked from the operation's span: file name as written, raw
  line/column for the location line, and the expanded line text, caret indent,
  caret width, and multiline flag for the excerpt — computed through
  [[Diagnostic Render]]'s exported excerpt geometry so the caret cannot drift
  from the interpreter's. Codes, messages, and help come from [[Diagnostic
  Arithmetic]] and, for the call-depth site, [[Diagnostic Evaluation]].
- Blocks retain lexical identities allocated by lowering; conditional and loop bodies use C braces, while value blocks use unique local names in the enclosing scope. A block result used
  as a value assigns a temporary (`CoreBlockValue`, `CoreIfValue`); a result
  that is discarded still emits its expression, because a discarded checked
  expression can still abort and must abort identically.
- `print` emits direct runtime calls: `pudu_print_int`, `pudu_print_bool`, or
  `pudu_print_str` with the literal's UTF-8 bytes and length baked in;
  `print(display(x))` is the same integer path, since `display` of an integer
  is its decimal form.
- Functions emit as `static` C functions whose result type is the core type's
  C spelling (`int64_t`, `int`, or `void`), parameters are the signature's
  locals in order, and every parameter and declared local gets a `(void)` use so
  `-Wextra` stays quiet. `return` inside a function is a plain C return; only
  the C `main` clamps.
- The C `main` is thin: when the module has calls it sets `pudu_depth = 1`
  first — the entry runs at depth 1 exactly as the evaluator counts it — then
  calls the entry function named by `coreModuleEntry` *directly*, never
  through a wrapper, because the evaluator's entry call has no call span and
  does not count against the limit. An `Int` result goes through
  `pudu_status`, a `()` result exits `0`, matching `reportResult`.
- Every call emits a wrapper invocation `pudu_call_<encoded-name>(&pudu_sites[i],
  args...)`: the site is the `E7002` call-depth site at the call's own span,
  and the wrapper checks and increments depth, calls the function directly,
  and decrements after a normal return. Each argument is assigned to a
  temporary in source order before the call, because C leaves argument
  evaluation order unspecified and the interpreter's is left to right; the
  wrappers exist for every reachable non-entry function, so no unused
  function can reach the translation unit.
- Eager binary operands become separate scalar temporaries before their consumer, preserving operator-tree grouping and left-to-right effects. Logical operators guard the entire right subtree with a C conditional. Comparisons consume scalar temporaries and emit unwrapped to avoid clang's `-Wparentheses-equality`.
- String literals and all baked text use one C escaper: printable ASCII
  verbatim, everything else, including question marks that could form C11 trigraphs, as octal `\NNN` bytes, so output bytes are exact
  under any compiler and locale.

## Negative Logic (Prohibited Paths)

- No `#line` directives, no compiler-specific extensions, no undefined
  behaviour: every arithmetic edge (INT64_MIN/-1, INT64_MIN negation, signed
  overflow in any helper) is checked before it executes.
- No reliance on evaluation order beyond what C11 guarantees: temporaries are
  emitted for `CoreIfValue` results and for every call argument, and helper
  arguments are plain values.
- No implicit declarations or unreachable top-level functions: every carried function is
  prototyped before it is called, wrappers exist for reachable non-entry callees, and the
  entry is never wrapped because C `main` calls it directly.
- No nondeterminism: no map iteration, no timestamps, no addresses, no
  environment reads.

## Dependencies and consumers

Requires [[Backend Emit State]], [[Backend Emit Support]], [[Pudu Core]], [[Source]], [[Diagnostic Render]] excerpt geometry,
[[Diagnostic Arithmetic]] and [[Diagnostic Evaluation]] text, and [[Backend
Runtime]]. Consumed by the `pudu build --native` path in [[Pudu CLI]]. It
imports no frontend, semantic, or evaluator module.

## Grill Log

- **Q:** Why bake a site table instead of passing `__FILE__`/`__LINE__` or
  `#line`? **A:** The interpreter's location and excerpt are facts about the
  Pudu source, not about generated C; the table carries exactly those facts,
  and `#line` would move C compiler errors onto Pudu lines while doing nothing
  for runtime refusals. _Rejected:_ macro-based location capture.
- **Q:** Why emit a call per checked operation rather than open-coded checks?
  **A:** One helper per operation is one place where the INT64 edge cases and
  the refusal text live; open-coding duplicates both across every expression
  and lets them drift. The compiler inlines the helpers back at `-O2`.
  _Rejected:_ per-site inlined check sequences.
- **Q:** Why are discarded results still emitted? **A:** `x + 1` as a
  statement can overflow and the interpreter aborts there; skipping the
  evaluation for a value nobody reads would silently change observable
  behaviour. _Rejected:_ dead-result elision in the first milestone.
- **Q:** Why do comparisons emit without parentheses? **A:** A comparison is
  the only operator clang warns about when doubly parenthesized
  (`-Wparentheses-equality` on `if ((a == b))`), and the toolchain contract is
  a warning-free build; emitting the comparison unwrapped keeps the policy
  without suppression pragmas. _Rejected:_ `-Wno-parentheses-equality` and
  blanket parenthesization with per-site exceptions.
- **Q:** Why one fixed layout instead of configurable formatting? **A:**
  Determinism is a promise; knobs are not. One fixed layout keeps golden tests
  meaningful and keeps the diff between two compilations empty. _Rejected:_
  configurable emission formatting.
- **Q:** Why does a call go through a wrapper instead of checking depth inside
  the callee? **A:** The evaluator's refusal happens in the caller, at the call
  site's span, before the callee runs; a check inside the callee would carry
  the wrong span and would count depth one call late. A wrapper is the call
  site's own code, so the site, the check, and the increment land exactly where
  the evaluator's `descend` is. _Rejected:_ in-callee depth checks.
- **Q:** Why is the entry called directly instead of through its wrapper?
  **A:** The evaluator enters the program with no call span and depth 0, so the
  entry body runs at depth 1; the C `main` reproduces that with
  `pudu_depth = 1` plus a direct call, and a wrapper would add a depth the
  interpreter never counts. _Rejected:_ wrapping the entry uniformly.
- **Q:** Why assign every call argument to a temporary? **A:** The interpreter
  evaluates arguments left to right and a checked operation inside an argument
  can abort, so the order is observable; C11 leaves argument evaluation order
  unspecified. Sequenced temporaries are the only portable way to reproduce
  the interpreter's order. _Rejected:_ inline argument expressions.
- **Q:** Why `(void)` uses for unread parameters? **A:** `-Wextra` flags an
  unused parameter and the toolchain contract is a warning-free build; a
  `(void)` use names the parameter without inventing a value or a suppression
  flag. _Rejected:_ `-Wno-unused-parameter`.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[src/Pudu/_MOC]] · [[Pudu Core]] ·
[[Backend Runtime]] · [[Backend Toolchain]] · [[Compiler Lower]] · [[Backend]]

## Production evaluation sequencing (#488)

[[Backend Emit State]] owns state, escaping and site geometry; [[Backend Emit Support]] owns runtime selection and signatures. Every eager binary operand is materialized in a separate C statement before the next operand starts, preserving both side effects and reads of mutable locals. Logical operators emit a conditional block around the entire right operand, including argument setup. Unary and call expressions are materialized by their eager binary consumers or by argument temporaries; a single-operand consumer may keep them inline. Every local receives a `(void)` use to keep unread bindings warning-free without suppressing compiler diagnostics. Wrappers are emitted for every reachable non-entry function, avoiding a second, lossy reachability walk.

Resolved Grill Log: C evaluation order cannot implement Pudu left-to-right semantics. Sequenced scalar temporaries preserve evaluation and grouping; guarded right operands preserve short circuit. Injective hexadecimal function symbols preserve distinct Unicode identifiers. Rejected: inline calls, unguarded preludes, and lossy sanitization.

## Resolved loop-control extension (#489)

Numeric loop destinations emit as function-local C labels. Continue labels precede all condition setup; break labels follow the loop body. Labels are emitted only when a generated transfer references them. Loop result slots are initialized scalar temporaries and are mapped by resolved identity while emitting nested regions. A break operand finishes evaluation before the destination slot is written or control transfers, so nested transfers preserve the interpreter's behavior. Body trailing values are evaluated and discarded. Never expressions emit their control effects without assigning a fabricated result to an enclosing destination; initialized join slots keep strict C11 flow analysis warning-free.

- **Q:** Can an outer break value overwrite its slot before an operand transfers elsewhere? **A:** No; the operand is emitted fully before assignment. Rejected: assignment before operand setup.
- **Q:** How are unused labels avoided? **A:** Emission records actual transfer references while capturing each loop region, then writes only referenced destination labels. Rejected: warning suppression or unconditional labels.

## Unit locals (#489)

Unit locals use an integer sentinel, never a C void value. Initializers and assignment operands execute for their effects before the sentinel is stored; reading or discarding a unit local has no effect. Resolved Grill Log: unit has a single inhabitant, so the sentinel carries no user-visible payload; discarded initializers must still preserve calls, diagnostics and transfers. Rejected: assigning a C void expression to an integer local.


## Unit literals and parameters (#492)

Unit call arguments execute once through emitDiscard, then bind integer zero to their temporary. Never use a void-returning helper call as an initializer. Keep source-order freezing for mixed unit/scalar arguments, transfer/error behavior and wrapper call-depth ordering. Existing C int unit parameter slots and void unit function results remain.

Resolved Grill Log: preserve the single unit inhabitant and every effect without allocating a new representation. Reject void-valued C initializers, Result erasure and omitted argument evaluation. Nonempty tuples remain pending; #493 implements unit display/equality.


## Unit display and equality (#493)

emitValue freezes a unit operand by emitting its effects once then assigning zero to a temporary. Both eager binary operands and call arguments share this helper. Inline unit display emits operand effects once then pudu_print_str for the two bytes (). Preserve guarded logical operands, transfer/failure order, call-depth site timing and strict-C11 warning policy.

Resolved Grill Log: unit has one value but its operands still execute. Reject skipped/repeated effects, void C initializers, wrong runtime printer selection and accidental ordered/arithmetic unit admission. Owned text representation and E7001 invalid-operation lowering remain separate obligations.
