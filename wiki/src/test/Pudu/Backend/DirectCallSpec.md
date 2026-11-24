---
type: module
path: "@root/test/Pudu/Backend/DirectCallSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, backend, native, direct]
aliases: [Native Direct Call Tests]
---

# Native Direct Call Tests

## Purpose

Evidence for [[Backend Frame Direct]], the direct bodies and inline calls of
[[Backend Frame Bodies]], and the direct export entry of [[Backend Emit Export]].

## Cases

| Case | Kind | Evidence |
| --- | --- | --- |
| `quad`, a non-recursive chain over `twice`, is selected; `main`, the recursive `fact`, the mutually recursive `isEven` and `isOdd`, and `apply` (which calls through a function value) are not | selection | the direct set contains `Main.quad` and none of the other four names |
| Owned text and records cross direct calls made from a recursive heap-path caller and from a direct caller | success, output | exact standard output, in order: `start(2,1)`, `p(1,-1)`, `p(11,-11)`, `p(21,-21)`, compiled with `cc -O2` under `-std=c11 -pedantic -Wall -Wextra -Werror` |
| Nested typed integer calls | success, output | strict C11 entry with typed parameters, unused parameters, signed division and remainder, and deferred signed magnitude fallback |
| Nested borrowed records | success, ownership | typed pointer parameter and unchanged scalar output after returning to the owning caller |
| A division by zero inside a direct function | failure, diagnostic | exit code 1 after printing `2`; the diagnostic names `Main.pudu:4`, the division line |
| An exported direct function | regression | its wrapper calls `pudu_direct_<n>` and never `pudu_run_active` |

When no `cc` executable is found, the two run cases report a skip and pass
without compiling.

## Grill Log

- **Q:** Why compare against fixed expected output rather than the tree evaluator?
  **A:** The expected lines are the evaluator's answers for these programs, written
  once; a fixed literal makes the native result reviewable at a glance.

## Referenced by

[[src/_MOC]] · [[Native Direct Calls Delivery]] · [[Backend Frame Direct]]
