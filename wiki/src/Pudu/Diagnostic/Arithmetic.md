---
type: module
path: "@root/src/Pudu/Diagnostic/Arithmetic.hs"
fidelity: Active
domain: "[[Diagnostic]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, diagnostics, runtime]
aliases: [Diagnostic Arithmetic, Checked Arithmetic Diagnostics]
---

# Diagnostic Arithmetic

## Purpose and interface

One home for the text of checked-arithmetic refusals, so the tree evaluator,
the unboxed loop path, and the native C runtime cannot drift apart in what a
programmer reads. The module owns the codes, messages, and help for the
overflow (`E7005`) and division-by-zero (`E7004`) refusals of `+ - * / %` and
unary `-`, as plain `Text` values; it builds no `Diagnostic` itself and
imports no evaluator.

```haskell
data CheckedOperation
  = CheckedAdd | CheckedSubtract | CheckedMultiply | CheckedDivide | CheckedNegate

checkedOperationName :: CheckedOperation -> Text

overflowCode :: Text        -- "E7005"
overflowMessage :: IntegerKind -> CheckedOperation -> Text
overflowHelp :: Text

divideByZeroCode :: Text    -- "E7004"
divideByZeroMessage :: Text
```

## Governance

- The message shape is the one the evaluator has always produced:
  `<Kind> cannot hold the result of this <operation>`, with the operation
  named as `add`, `subtract`, `multiply`, `divide`, or `negate`.
- The help text is the single constant the evaluator already used, including
  its exact wording and punctuation.
- [[Backend Emit]] bakes these same values into generated C site tables, and
  [[Backend Runtime]] prints them verbatim, so native refusals are byte-equal
  to interpreted ones by construction rather than by convention.
- Changing any string here is a public-language change: it changes what every
  program prints when it fails, under every execution path.

## Negative Logic (Prohibited Paths)

- No `Diagnostic` construction, no spans, no rendering, no severity, no
  colour; those belong to [[Diagnostic Model]] and [[Diagnostic Render]].
- No new message variants: wrapping and saturating forms never abort, so they
  have no entry here.

## Dependencies and consumers

Requires [[Integer Literal]] for `IntegerKind` and its name. Consumed by
[[Eval Operator]], [[Eval Loop Unboxed]], [[Compiler Lower]], [[Backend Emit]],
and, through the emitted site table, [[Backend Runtime]].

## Grill Log

- **Q:** Why a module rather than three copies of two strings? **A:** The
  native path makes the strings observable in a second language (C), and
  `test/diagnostic-codes.mjs` already treats "one code, one module" as the
  invariant; three literal `"E7005"` sites would be the drift the registry
  exists to catch. _Rejected:_ literal codes per call site.
- **Q:** Why does the unboxed path switch to these builders when it was built
  to avoid shared machinery? **A:** The builders are used only on the refusal
  path, after the region has already stopped; they cost nothing on the hot
  path and make refusal parity structural. _Rejected:_ a second copy of the
  strings in `Unboxed`.
- **Q:** Why `CheckedOperation` instead of passing the operation word? **A:**
  The five words are a closed set fixed by the language; an enum makes an
  unknown operation a compile error rather than a new message at runtime.
  _Rejected:_ free-form operation text.

## Referenced by

[[src/Pudu/_MOC]] · [[Eval Operator]] ·
[[Eval Loop Unboxed]] · [[Compiler Lower]] · [[Backend Emit]] ·
[[Diagnostic Model]]

## Platform Int operators (#495)

Export shiftCode, negativeShiftMessage, negativeShiftHelp, wideShiftMessage :: IntegerKind -> Text and wideShiftHelp. Preserve exact existing interpreter E7004 text; messages carry no spans or rendering.

Resolved Grill Log: use defined unsigned bit patterns, validate counts before shifts, and prove signed arithmetic bounds before evaluation. The actual interpreter determines results, effect order and exact diagnostic vocabulary. No syntax or type-inference change.
