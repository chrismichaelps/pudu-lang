---
type: module
path: "@root/src/Pudu/Eval/Match.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Eval Match]
---

# Eval Match

## Purpose

Own total pattern matching and admitted literal-to-runtime conversion for [[Evaluator]].

## Interface

The exported signatures are the module header's export list; [[Evaluator]] is the only consumer, and every function here is total with respect to the values the earlier phases admit.

### Governance

- Data and mechanics only: nothing here decides program meaning that [[architecture/SEMANTICS]] assigns to another phase.
- Failures are reported as `E7xxx` diagnostics through [[Eval Env]], never as host exceptions or partial values.
- Every operation is defined for the value shapes the evaluator can produce, and says so explicitly for the shapes it cannot.
- Integer expressions and pattern endpoints decode through [[Integer Literal]], so a suffix affects static selection but never contaminates the arbitrary-precision interpreter value.
- Floating expressions and pattern endpoints decode through [[Float Literal]], retaining `Float32`/`Float64` width and the normalized selected-precision value.

- **A record pattern that names something must match that name.** A record type has one shape, so its own pattern could ignore the tag and nothing depended on it; a variant that names its payload does not. `Add` and `Mul` may declare the same fields, and matching on fields alone let the first arm accept the other's value — a program that read `case Add{left, right}` and computed a product, with no diagnostic anywhere.
- A pattern that names nothing still matches any record, which is what an unqualified `case {value}` has always meant.

- **A number is the same number whatever width holds it.** `==` meets the two widths and compares what they hold, and matching says the same thing. Structural equality was what made them disagree — it compares the width tag as though it were part of the value, so `7i8` did not match `case 7` and fell to the wildcard while `a == 7` on the next line was true. Aggregates compare by their parts, so a number nested in a tuple or a variant is judged the same way as one that is not.

- **A number is the same number whatever width holds it.** `==` meets the two widths and compares what they hold, and matching says the same thing. Structural equality was what made them disagree — it compares the width tag as though it were part of the value, so `7i8` did not match `case 7` and fell to the wildcard while `a == 7` on the next line was true. Aggregates compare by their parts, so a number nested in a tuple or a variant is judged the same way as one that is not.

- **A literal is built as the kind inference gave it.** A suffix still wins where there is one, since it said the kind outright; where there is neither a suffix nor an answer from the checker, the platform integer is the default the checker itself would have chosen.

### Linkage

- **Requires:** [[Eval Value]], [[Syntax Tree]], [[Integer Literal]], [[Float Literal]], [[Diagnostic Model]].
- **Consumed by:** [[Evaluator]].

## Algorithm

Direct structural recursion over the value or syntax shape; no caching, no mutation, no reflection.

## Negative Logic (Prohibited Paths)

- No typing, coercion, dispatch, IO, or ownership behaviour.

## Edge Cases

- A shape this module cannot handle produces a diagnostic naming the shape, never a default value.

## Depth

DEPTH 0.45 (MEDIUM). It keeps one concern out of [[Evaluator]], which would otherwise exceed the size the delivery rules allow.

## Grill Log

- **Q:** Why not compare widths in both places instead? **A:** Because the width is not part of the number. _Rationale:_ `7i8` and `7` denote the same integer and the language already says so everywhere else — arithmetic meets the two kinds rather than refusing them — so making `==` structural would refuse comparisons every program makes. _Rejected:_ comparing width tags in both places; a separate pattern form for widths.
- **Q:** Why not make matching structural and equality structural too? **A:** Because the width is not part of the number. _Rationale:_ `7i8` and `7` denote the same integer, and the language already says so everywhere else — arithmetic meets the two kinds rather than refusing them. Making `==` structural instead would refuse comparisons every program makes. _Rejected:_ comparing width tags in both places; a separate pattern form for widths.
- **Q:** Why did ignoring the tag ever work? **A:** Because until variants could name their payload, a record pattern could only name a record type, and a value of the wrong type never reached the match. _Rationale:_ the checker guaranteed what the matcher assumed, so the assumption was invisible until the checker stopped guaranteeing it. _Rejected:_ leaving the tag to the checker, which cannot tell two variants of one type apart at a match arm.
- **Q:** Why a separate module rather than more of [[Evaluator]]? **A:** Because the walker would pass 500 lines and stop being reviewable. _Rationale:_ the split follows a real seam — values, environment, matching, and operators are independently testable. _Rejected:_ one large evaluator file.
- **Q:** Reparse suffixed integers with host `read`? **A:** No; use [[Integer Literal]]'s total arbitrary-precision decoder. _Rationale:_ type checking and evaluation must agree on bases, separators, suffix removal, and sign. _Rejected:_ permissive partial `reads`; silently keeping the suffix in host input.
- **Q:** Let pattern floats parse separately from expression floats? **A:** No; use [[Float Literal]] for both. _Rationale:_ width, rounding, overflow admission, and suffix stripping must agree before runtime matching. _Rejected:_ raw `reads Double`; erasing an `f32` pattern to binary64.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]]
