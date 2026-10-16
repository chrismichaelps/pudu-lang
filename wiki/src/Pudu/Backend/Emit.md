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
  followed by a blank line), the site table, then functions.
- Runtime selection is a walk over the core module (`runtimeNeeds`): every
  program carries the prelude and the status clamp; a checked operation adds
  the site table, the colour decision, the refusal renderer, and its own
  helper; each printer adds itself. Selection is a pure function of the
  module, so unused helpers never enter the translation unit and the build
  stays warning-free.
- Locals emit as `int64_t pudu_v<id>` / `int pudu_v<id>`; temporaries as
  `int64_t pudu_t<n>` per function; names are never derived from source names,
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
  Arithmetic]].
- Blocks emit as C blocks, so Pudu scoping is C scoping. A block result used
  as a value assigns a temporary (`CoreBlockValue`, `CoreIfValue`); a result
  that is discarded still emits its expression, because a discarded checked
  expression can still abort and must abort identically.
- `print` emits direct runtime calls: `pudu_print_int`, `pudu_print_bool`, or
  `pudu_print_str` with the literal's UTF-8 bytes and length baked in;
  `print(display(x))` is the same integer path, since `display` of an integer
  is its decimal form.
- The program entry emits the block, then `return pudu_status(<result>)`;
  `CoreReturn` emits `return pudu_status(...)` / `return 0` directly, so early
  returns and the final result clamp identically to `reportResult`.
- String literals and all baked text use one C escaper: printable ASCII
  verbatim, everything else as `\xNN` bytes, so output bytes are exact under
  any compiler and locale.
- Parenthesization is deliberate: `&&`/`||` and mixed binary operands are
  wrapped, but a comparison emits unwrapped, because `if ((a == b))` draws
  clang's `-Wparentheses-equality` under the fixed warning policy.

## Negative Logic (Prohibited Paths)

- No `#line` directives, no compiler-specific extensions, no undefined
  behaviour: every arithmetic edge (INT64_MIN/-1, INT64_MIN negation, signed
  overflow in any helper) is checked before it executes.
- No reliance on evaluation order beyond what C11 guarantees: temporaries are
  emitted for `CoreIfValue` results, and helper arguments are plain values.
- No nondeterminism: no map iteration, no timestamps, no addresses, no
  environment reads.

## Dependencies and consumers

Requires [[Pudu Core]], [[Source]], [[Diagnostic Render]] excerpt geometry,
[[Diagnostic Arithmetic]] text, and [[Backend Runtime]]. Consumed by the
`pudu build --native` path in [[Pudu CLI]]. It imports no frontend, semantic,
or evaluator module.

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

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[src/Pudu/_MOC]] · [[Pudu Core]] ·
[[Backend Runtime]] · [[Backend Toolchain]] · [[Compiler Lower]] · [[Backend]]
