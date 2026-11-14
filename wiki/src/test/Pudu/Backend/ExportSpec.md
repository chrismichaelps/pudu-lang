---
type: module
path: "@root/test/Pudu/Backend/ExportSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, backend, native, mobile]
aliases: [Backend Export Tests]
---

# Backend Export Tests

## Purpose

Evidence for [[Backend Emit Export]] and the library roots of
[[Compiler Lower]].

## Cases

| Case | Kind | Evidence |
| --- | --- | --- |
| A C host starts the program, then calls exports with `Int64`, `Int32 -> Bool`, `Float64`, `UInt8`, and a `()` export that prints | success, output | exact standard output in call order, including Pudu output flushed before each export returns, under `-std=c11 -pedantic -Wall -Wextra -Werror` |
| An export called before `pudu_program_run` | failure, diagnostic | the process stops with the line naming the export and the missing start |
| An export taking `Str` | failure | emission refuses the parameter C cannot pass |
| Exports with type parameters or defaults | failure | E6001 refusals at each name |
| The same exports in an executable build | regression | lowering ignores exports entirely |

## Grill Log

- **Q:** Compile the host and the unit separately as a real application would?
  **A:** Yes. _Rationale:_ a separate translation unit proves the header's
  prototypes match the definitions and that no other symbol leaks.

## Referenced by

[[src/_MOC]] · [[Backend Emit Export]] · [[Native Calls Delivery]]
