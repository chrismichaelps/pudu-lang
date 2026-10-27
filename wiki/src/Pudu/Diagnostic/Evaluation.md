---
type: module
path: "@root/src/Pudu/Diagnostic/Evaluation.hs"
fidelity: Active
domain: "[[Diagnostic]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, diagnostics, runtime]
aliases: [Diagnostic Evaluation, Evaluation Diagnostics]
---

# Diagnostic Evaluation

## Purpose and interface

One home for the text of evaluation-phase refusals that a *running* program can
surface, so the tree evaluator and the native C runtime cannot drift apart in
what a programmer reads. The module owns the call-depth refusal (`E7002`): the
code, the message, and the help the interpreter prints when recursion passes
the evaluator's bound.

```haskell
callDepthCode :: Text      -- "E7002"
callDepthMessage :: Text   -- "call depth exceeded the evaluation limit"
callDepthHelp :: Text      -- "the interactive evaluator bounds recursion"
```

## Governance

- The wording is the interpreter's own, unchanged — including "the interactive
  evaluator bounds recursion". A natively built program is not interactive, but
  native output must equal interpreted output byte for byte; rewording is a
  public-language change and a separate decision, not a side effect of the
  backend.
- [[Eval Env]]'s `descend` builds its refusal from these values, and
  [[Backend Emit]] bakes the same values into the site of every call, so the
  two renderings are equal by construction and the differential conformance
  tests then prove the renderers agree.
- The loop step-limit refusals share the `E7002` code but stay evaluator-owned:
  they are compile-time-phase diagnostics that no native program can print,
  because runtime loops are unrestricted ([[Compile Time Limits]]).
- Changing any string here is a public-language change: it changes what every
  program prints when recursion runs away, under every execution path.

## Negative Logic (Prohibited Paths)

- No `Diagnostic` construction, no spans, no rendering, no severity, no
  colour; those belong to [[Diagnostic Model]] and [[Diagnostic Render]].
- No limit value: the bound itself lives in [[Compile Time Limits]]; this
  module carries only what the reader sees.

## Dependencies and consumers

Requires only `Data.Text`. Consumed by [[Eval Env]] and, through the emitted
site table, [[Backend Emit]] and [[Backend Runtime]].

## Grill Log

- **Q:** Why a module rather than literals at the two call sites? **A:** The
  native path makes the strings observable in a second language (C), and
  `test/diagnostic-codes.mjs` already treats "one code, one module" as the
  invariant; literal copies would be the drift the registry exists to catch.
  _Rejected:_ literal codes per call site.
- **Q:** Why keep "interactive evaluator" in the help text when the native
  runtime prints it? **A:** The interpreter is the semantic oracle and the
  conformance contract is byte equality; a wording change would be a
  language-facing decision across every execution path, not a backend detail.
  _Rejected:_ a native-specific help string.
- **Q:** Why not move the loop step-limit text here too? **A:** Those refusals
  can only arise during compile-time execution, which the native runtime never
  performs; moving them would imply a parity obligation that does not exist.
  _Rejected:_ one `E7002` text module for both.

## Referenced by

[[src/Pudu/_MOC]] · [[Eval Env]] · [[Backend Emit]] · [[Backend Runtime]] ·
[[Diagnostic Arithmetic]] · [[Diagnostic Model]]
