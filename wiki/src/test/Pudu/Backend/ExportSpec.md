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
| An export taking `Array[Int64]` | failure | emission refuses the parameter C cannot pass |
| embedded exports carry text, records and Result to a C host | success, output | a host calls `shout` (text in and out, owned terminated result), `moved` (flat record both ways), `describe` and `tag` (a nested record with a text field, in and out), `half` (`Result[Int64, Str]`: Ok with value, Err with text, null out pointers) and `check` (`Result[(), Str]`), releasing every text result with `pudu_string_release`; the output must be exactly `ready`, `hi! 3 1`, `11 12`, `pin@3`, `pin+ 4`, `0 4`, `1 odd 7`, `0`, `0 1 not positive` |
| embedded exports refuse host text that is not UTF-8 | failure, diagnostic | a host passes the single byte 0xFF; the process stops and standard error names `pudu_export_shout ... with text that is not UTF-8` |
| Exports with type parameters or defaults | failure | E6001 refusals at each name |
| The same exports in an executable build | regression | lowering ignores exports entirely |

## Grill Log

- **Q:** Compile the host and the unit separately as a real application would?
  **A:** Yes. _Rationale:_ a separate translation unit proves the header's
  prototypes match the definitions and that no other symbol leaks.

## Referenced by

[[src/_MOC]] · [[Backend Emit Export]] · [[Native Calls Delivery]]
