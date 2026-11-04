---
type: handoff
status: ACTIVE
issue: 525
aliases: [Native Sum Delivery]
---
# Native Sum Delivery

Delivery Owner → Backend Engineer → Test Engineer. Stacks on #521 (97d1706f), with the #536 checker
repair cherry-picked so qualified variants are typed.

Owned: Core.hs, Core/Frame.hs, Compiler/Lower/{Types,Scalar,Body,Record,Tuple,Sum,Match,Layout}.hs,
Compiler/Frame{,/Body,/State,/Match}.hs, Backend/Emit/{Aggregate,Frame,Frame/Value,Frame/Body,State}.hs,
Backend/Runtime{,/Text}.hs, Type.hs (`declaredSums`), SumPrograms.hs, NativeSpec, TextLeakSpec,
FrameSpec, WideFrameSpec, both cabal files and mirrors.

Findings while finishing:
- Operator failures on sums named the static type; the evaluator names the held variants. Native now
  builds the message at run time from the shared wording.
- `Shape.Circle(3)` was typed as the error type by the checker (#536), so native could not lower it.
- E7011 is unreachable from checked programs, because matches must be exhaustive.
- A differential run of every fixture with `main` shows almost every program refused for using
  imports, so modules and constants are the next row with the largest effect.

Evidence: [[Backend Sum Programs]] passes under Clang, GCC 15 and Clang ASan/UBSan, and the counted-leak
run includes it.

Exact next action: run the clean gates on this commit, then begin native modules and imports (a new
issue), measuring progress with the fixture differential run.

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]]
