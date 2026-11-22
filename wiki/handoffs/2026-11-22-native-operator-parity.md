---
type: handoff
status: ACTIVE
issue: 956
aliases: [Native Operator Parity Delivery]
---

# Native Operator Parity Delivery

Architect → Backend Engineer. The branch starts from fetched dev at
`9e63cada`. This pass covers [[Compiler Lower Scalar]], [[Compiler Lower Array]],
[[Backend Frame Values]], [[Backend Runtime Array]], [[Backend Array Programs]],
[[Backend Tuple Programs]], [[Backend Range Programs]], [[Backend Abstraction Programs]],
[[Backend Foreign Programs]], [[Backend Emit Cell]], [[Backend Frame Program]],
[[Native Aggregate Emission]], [[Compiler Lower Foreign]], [[Compiler Lower Body]],
[[Compiler Lower Types]],
and this coverage record.

The dependency check starts with cell carriers, then follows runtime helpers,
frame dispatch, and checked lowering. Typed non-text arrays share the array
length carrier and can join when empty. Dynamic text members use checked
variant extraction before the text join. Checked unary operations with
no implementation should run their operands and report E7001. Nested tuple
comparability already has a runtime guard and needs evidence for held
callables and empty alternatives. The merged corpus gate covers slice and
derive diagnostics from the earlier continuation.

Backend Engineer → Test Engineer. Dynamic operator dispatch now selects
the held carrier, including mixed integer cases. Callback tokens share
canonical rendering for displays, aggregate members and entry results.
Dynamic display and show keep their respective payload renderers.

The optimized build passes. All 29 standalone cases match the interpreter
on stdout, stderr, and exit status under strict C11 with both compilers.
The instrumented run reports no address or undefined behavior failures.
The six focused properties also passed, including qualified use and mutable
writeback through a callable crossing.

## Audit findings and repairs

Three programs passed checking and confirmed a remaining gap. The foreign
declaration `magnitude(Int32) -> Int32` fails when bound to a local before
calling it. The interpreter returns 3, while the native build reports
E6001 at `magnitude`. Greater-than on tuples holding dynamic integers 6 and
1i8 returns true in the interpreter and false natively. A callback
constructor named `Main.Visit` shows as `<callback registration Main.Visit>`
in the interpreter and `<fn Visit>` natively. Registered tokens are covered
by the completed cases.

Architect → Backend Engineer → Test Engineer. The three reproductions
now agree through the native entry. Added coverage exercises an indirect
loader failure's call site, stored and qualified foreign calls, mutable
run writeback, retained registration, and mixed numeric tuple and set
ordering.

## Next action

Carry absence through the callable ABI for a stored foreign function with
a nullable mutable array parameter.

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]] · [[CHANGELOG]]
