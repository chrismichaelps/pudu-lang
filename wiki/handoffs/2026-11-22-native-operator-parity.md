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

## Aggregate ordering continuation

Architect → Backend Engineer. The checker reserves nullable loans for direct
calls under E3102. The native completion ledger tracks checked programs.

This continuation owns [[Native Aggregate Emission]], [[Backend Abstraction
Programs]], and the corresponding ledger and history entries. Dynamic
ordering follows the held shape after handling numeric comparisons. A
concrete sum uses the active variant shape before comparing variant names.

## Dynamic destination carriers

Backend Engineer. This pass extends [[Compiler Lower Place]], [[Compiler
Lower Record]], [[Compiler Lower Array]], [[Compiler Lower Keyed]],
[[Compiler Lower Loan]], and [[Type Check Statement]]. Checked dynamic
destinations now admit concrete values in record replacements, nested
assignments, array and keyed arguments, contextual sets, and ordinary
parameters beside a mutable loan. [[Backend Abstraction Programs]] holds
the native comparisons for these paths. [[Compiler Lower Method]] forwards
named exclusive parameters through dynamic dispatch, with writeback
covered by [[Backend Mutable Loan Programs]].

Method schemes currently require full source arity even where the written
declaration has defaults. Omission fails during checking and creates
no native-only refusal.

## Dynamic control flow and narrowing

Architect → Backend Engineer. [[Compiler Lower Control]] and [[Compiler
Lower State]] keep expected and observed loop results separate, so labelled
breaks widen at their target while diverging operands transfer directly.
[[Compiler Lower Body]], [[Compiler Lower Match]] and [[Compiler Lower
Dynamic]] project conditional and match results into checked aggregate
carriers and narrow dynamic patterns by canonical owner. The additions to
[[Backend Abstraction Programs]] and [[Backend Shape Programs]] are ready
for the integrated validation phase.

## Dynamic provider and payload identities

Architect → Backend Engineer. [[Type Check Method]] preserves the
selected canonical trait for dynamic calls. [[Compiler Lower Method]],
[[Compiler Lower Dynamic]] and [[Compiler Lower Match]] use the held
type for implementation lookup, widening and narrowing while keeping
the variant tag local to its layout. [[Backend Shape Programs]] covers
colliding trait display names. [[Backend Control Programs]] covers
transfers from arguments before invocation and writeback.

Generic widening must discover concrete, proven pairs of trait and
payload. Listing every type that structurally matches an implementation
head would also admit unused types and types whose conditional bounds
fail. Checked obligations must carry the payload and preserve rigid
parameters until the reachable copy settles them.

## Proven generic dynamic payloads

Architect → Backend Engineer. [[Type Env]], [[Type Check Method]],
[[Type Check]], [[Type Boundary]] and [[Compiler Pipeline]] publish successful
widenings to the analysis product. [[Compiler Lower]] settles the variant
table from concrete facts and proofs instantiated in visited copies.
[[Compiler Lower Dynamic]] assigns separate tags to concrete applications
of one owner, and [[Compiler Lower Match]] tests each such tag during
nominal narrowing. [[Backend Shape Programs]] exercises direct and
in-body generic widenings, method dispatch and common-field bindings.

## Cross-layout comparison

Architect → Backend Engineer. [[Backend Cross Comparison]] owns a
demand-selected helper graph for different concrete payload layouts.
[[Native Aggregate Emission]] dispatches from tag pairs into that graph.
[[Compiler Lower Scalar]] keeps the direct numeric rule ahead of the
aggregate equality path. [[Backend Shape Programs]] covers nested arrays,
generic sums, ordered keys and maps.

## Dynamic text members

Architect → Backend Engineer. [[Compiler Lower Method]] dispatches a
selected trait member normally. [[Compiler Lower Method Value]] selects
the held value for a universal dynamic text call or member read. Direct
calls can write back a selected mutable receiver. Stored closures capture
that receiver at selection. [[Backend Method Value Programs]] covers
overrides, fields, builtin selection and writeback.

## Dynamic runtime result consumers

Backend Engineer. [[Compiler Lower Call]] and [[Compiler Lower Method
Value]] render direct universal text results before joining heterogeneous
arms for immediate output, show and display. A uniform native result
retains its actual carrier. [[Compiler Lower Method]] preserves the
runtime failure of calling a numeric field. [[Backend Emit Cell]],
[[Native Aggregate Emission]] and [[Backend Frame Values]] report the
held kind in diagnostics. [[Backend Method Value Programs]] and
[[Backend Keyed Programs]] cover these cases.

## Stored runtime callable carriers

Architect → Backend Engineer. [[Core Module]], [[Compiler Lower Types]]
and [[Compiler Lower Dynamic]] represent heterogeneous runtime results
as a reserved sum of concrete carriers. [[Compiler Lower Method Value]]
retains the selected callable, including byte decoding. [[Compiler Lower
Lambda]] invokes the held carrier without changing the frame calling
convention. [[Compiler Lower Call]] and [[Compiler Lower Scalar]] consume
the selected result. [[Backend Method Value Programs]] covers local
annotations, receiver rebinding, callable identity and rendered output.

## Internal runtime call carriers

Architect → Backend Engineer. [[Compiler Lower Call]] registers internal
copies with concrete argument carriers. [[Compiler Lower]] replays its
worklist with newly observed result carriers so [[Compiler Lower
Signature]], [[Compiler Lower Body]] and [[Compiler Lower Function Body]]
agree on the final frame ABI. [[Compiler Lower Lambda]] uses that ABI
when a named function is retained as a callable. [[Backend Method Value
Programs]] covers early returns, defaulted arguments and multiple
ordinary function boundaries.

## Array runtime element carriers

Architect → Backend Engineer. [[Compiler Lower Array]] chooses a
layout at construction and copies retained entries when widening it.
[[Compiler Lower Place]], [[Compiler Lower Body]], [[Compiler Lower
Slice]], [[Compiler Lower For]] and [[Compiler Lower Method Value]]
use the held layouts for assignments, slices, iteration and bound
methods. [[Backend Method Value Programs]] covers these paths. Build
and execution checks are deferred until the emission implementation is
complete.

## Array and range callbacks

Architect → Backend Engineer. [[Compiler Lower Array]] and
[[Compiler Lower Range]] use exact callback and accumulator layouts.
[[Compiler Lower Generic]] shares native signature copies across
named callbacks and direct calls. [[Compiler Lower Lambda]] tracks
explicit and trailing results of lifted bodies. [[Backend Method
Value Programs]] covers mapping, filtering, ordering, joining, and
reduction with changing accumulator values. Execution checks remain
deferred until the emission implementation is complete.

## Stored callable dispatch

Architect → Backend Engineer. [[Compiler Lower]] discovers reachable
callable bodies and replays a call when a template becomes available.
[[Compiler Lower Lambda]] selects named and lifted bodies by native
target and retargets the kept captures. [[Compiler Lower Array]] and
[[Compiler Lower Sort]] call the resulting carrier at each traversal step.
[[Backend Method Value Programs]] covers stored callbacks returned by
functions, direct calls and array traversal with retained captures.
Build and execution checks remain deferred.

## Stored method and builtin input layouts

Architect → Backend Engineer. [[Compiler Lower Method Value]] records
the checked call recipe and receiver layout. [[Compiler Lower Method]]
copies synchronous implementation bodies for their actual arguments.
[[Compiler Lower Intrinsic]], [[Compiler Lower Call]] and [[Compiler
Lower Stop]] share runtime input selection for rendering, output and
panic. [[Backend Method Value Programs]] and [[Backend Rendering
Callable Programs]] cover changed arguments and receiver capture.

## Tuple and record layouts

Architect → Backend Engineer. [[Core Module]] and [[Compiler Lower
Types]] keep the declared record identity separate from its native field
layouts. [[Compiler Lower Record]], [[Compiler Lower Tuple]] and
[[Compiler Lower Dynamic]] retain the selected member through
construction, projection and updates. [[Compiler Lower Body]] and
[[Compiler Lower Match]] join compatible products and normalize products
with several known layouts before binding their fields. [[Backend Shape
Programs]] covers nested values, aliases and multiple return paths.

## Sum payload layouts

Architect → Backend Engineer. [[Compiler Lower Sum]] projects named
and positional payloads to native layouts. [[Compiler Lower Dynamic]]
normalizes variants for [[Compiler Lower Match]] and branch joins.
[[Compiler Lower Try]] rebuilds a selected failure for its enclosing
frame and preserves scope joins. [[Backend Shape Programs]] covers
construction, tag selection and propagation. Execution is deferred.

## Keyed collection layouts

Architect → Backend Engineer. [[Compiler Lower Keyed]] constructs and
rebuilds maps, sets and stores with their actual key and value layouts.
[[Compiler Lower For]], [[Compiler Lower Method Value]] and [[Compiler
Lower Intrinsic]] preserve those layouts at iteration and callable
boundaries. [[Backend Keyed Programs]] and [[Backend Store Programs]]
cover retained aliases, updates and absent keys. Execution is deferred.

## Task result layouts

Architect → Backend Engineer. [[Compiler Lower Signature]] and
[[Compiler Lower Lambda]] settle native task results. [[Compiler Lower
Body]] awaits selected tasks. [[Compiler Lower Scope]] probes known
compatible failure layouts and rebuilds the enclosing result. [[Compiler
Lower Function Body]] reports the held result at the async entry.
[[Backend Shape Programs]] covers deferred calls and joined task failures.

## Mutable loan layouts

Architect → Backend Engineer. [[Compiler Lower Loan]] selects direct
and indirect bodies from the actual argument layouts and projects each
final to the held place. [[Compiler Lower Lambda]] and [[Compiler Lower
Method Value]] settle ordinary results independently of mutable
finals. [[Compiler Lower Method]] joins compatible dynamic arms.
[[Backend Shape Programs]] covers fields, retained aliases and indexed
arguments. Execution remains deferred.

## Mutable slot layout discovery

Architect → Backend Engineer. [[Compiler Lower]] replays mutable
declarations when their slots need wider layouts. [[Compiler Lower
Place]] records requirements through fields and array elements.
[[Compiler Lower Signature]], [[Compiler Lower Generic]] and
[[Compiler Lower Loan]] propagate demands through named mutable
parameters and back to their callers. [[Backend Shape Programs]]
covers later writes, repeated branches and retained aliases.

## Stored mutable parameter layouts

Architect → Backend Engineer. [[Compiler Lower State]] identifies
mutable parameters by body and position. [[Compiler Lower Lambda]]
and [[Compiler Lower Method Value]] replay stored bodies with the
settled layouts and retain their captures. [[Compiler Lower Loan]]
projects the actual argument and final through the original place.
[[Backend Shape Programs]] covers a captured lambda and bound method.

## Selected text and byte receivers

Architect → Backend Engineer. [[Compiler Lower Text]] and [[Compiler
Lower Bytes]] select supported methods on the held receiver, and
[[Compiler Lower Method]] resolves a retained nominal implementation.
[[Compiler Lower Method Value]] preserves selected captures.
[[Compiler Lower Array]] and [[Compiler Lower Slice]] evaluate the
key before reporting invalid indexing. [[Backend Rendering Callable
Programs]] covers successful access and failure ordering.

## Selected method and primitive arguments

Architect → Backend Engineer. [[Compiler Lower Arguments]] holds
operands before checking their layouts. [[Compiler Lower Text]]
and [[Compiler Lower Bytes]] use it for methods and text-view
operations. Byte construction validates each selected array element
in order and [[Compiler Lower Intrinsic]] registers the stored
specializations. [[Backend Rendering Callable Programs]] covers
successful operations, transfers, later effects and diagnostic
attribution. Execution remains deferred.

## Wider integer positions

Architect → Backend Engineer. [[Compiler Lower Arguments]] retains
integer kinds through operand selection. [[Compiler Lower Text]]
checks exact view positions and repeat limits. [[Compiler Lower
Bytes]] validates group shape before clamping. [[Compiler Lower
Array]] selects bracket keys and reuses index bounds diagnostics.
[[Backend Rendering Callable Programs]] covers both call forms,
huge values in both directions and reversed group widths.

## Exact written slice bounds

Architect → Backend Engineer. [[Compiler Lower Slice]] retains the
receiver and both endpoints, validates their held layouts, and
compares the original integers before narrowing. Written and stored
slice keys share the same bounds checks. [[Backend Rendering Callable
Programs]] covers inclusive bounds, Unicode, unsupported endpoints,
and transfer before type validation.

## Exact stored range bounds

Architect → Backend Engineer. [[Compiler Lower Range]] and [[Compiler
Lower Constant]] retain original endpoint values. [[Native Range Runtime]]
uses those values for storage, comparison, containment, materialization
and exact progression sums. [[Compiler Lower Slice]] checks stored
endpoints before narrowing, and [[Compiler Lower For]] streams the held
interval. [[Backend Rendering Callable Programs]] covers these paths.
Execution remains deferred.

## Exact Int runtime identity

Architect → Backend Engineer. [[Integer Literal]] defines an internal
exact layout with Int runtime identity. [[Backend Emit Support]]
and [[Native Aggregate Emission]] retain its payload in frames and
aggregates. [[Compiler Lower Scalar]] preserves checked bounds
and exact comparisons. [[Compiler Lower Convert]] and
[[Compiler Lower Intrinsic]] select typed conversions from the held
integer. [[Backend Rendering Callable Programs]] covers calls,
wrapping arithmetic and overflow. Execution remains deferred.

## Dynamic exact Int payloads

Architect → Backend Engineer. [[Compiler Lower Types]] provides the
exact payload layout under the existing Int implementation identity.
[[Compiler Lower Dynamic]], [[Compiler Lower Call]] and [[Compiler
Lower Body]] project selected payloads into this layout. [[Compiler
Lower Method]] reprojects mutable finals. [[Compiler Lower Scalar]]
validates the selected logical integer kind. [[Backend Rendering
Callable Programs]] covers retained methods, equality, set deduplication,
writeback and diagnostic behavior. Execution remains deferred.

## Held collection member selection

Architect → Backend Engineer. [[Compiler Lower Body]] selects the
held array, keyed collection or range before argument lowering.
[[Compiler Lower Array]], [[Compiler Lower Keyed]] and [[Compiler
Lower Range]] receive the selected value. [[Compiler Lower Dynamic]]
retains the member lookup failure before argument effects. Keyed
lookup results use the held value layout. [[Backend Rendering
Callable Programs]] covers shared members and absent methods.

## Held collection method arguments

Architect → Backend Engineer. [[Compiler Lower Arguments]] supplies
shape-aware argument slots. [[Compiler Lower Array]] and [[Compiler
Lower Keyed]] preserve held operands, position conversion and diagnostic
attribution. [[Compiler Lower Range]] and [[Native Range Runtime]] use
the exact stride. [[Eval Range]] avoids narrowing positive strides
and visits only selected terms. [[Backend Rendering Callable Programs]]
covers wrapped positions, alternate keys, stride and argument failures.
Execution remains deferred.

## Traversal callback validation

Architect → Backend Engineer. [[Compiler Lower Array Loop]] owns
callback invocation and predicate checks after traversal reaches an
item. Held builtin callbacks fail at invocation. Array predicates
require Bool, and range filters keep only true. [[Backend Rendering
Callable Programs]] covers empty traversal, stored methods, and
effects before rejection. Execution remains deferred.

## Callback defaults and arity

Architect → Backend Engineer. [[Compiler Lower Array Loop]] selects
the held callable's parameter profile and supplies its hidden
argument count. [[Compiler Lower Default]] evaluates omitted defaults
and reports required parameters in declaration order. [[Native
Frame Lowering Tests]] covers padding, missing arguments and excess
arguments. Execution remains deferred.

## Held declared method calls

Architect → Backend Engineer. [[Compiler Lower Method]] retains the
receiver and selects its ordinary instance before argument evaluation.
[[Compiler Lower Body]] and [[Compiler Lower Text]] route selected
receivers through field, builtin and declared member lookup.
[[Backend Rendering Callable Programs]] covers different result layouts,
missing members and callback arity. Execution remains deferred.

## Held declared method values

Architect → Backend Engineer. [[Compiler Lower Method Value]] selects
and captures the held member before the source binding can change.
[[Compiler Lower Method]] uses the selected declaration's bound fact
for ordinary calls. [[Backend Rendering Callable Programs]] covers
reassignment, function-valued fields and failure at capture.

## Declared method argument counts

Architect → Backend Engineer. [[Compiler Lower Default]] validates
the selected implementation's written slot count. [[Compiler Lower
Method]] forwards the supplied count, including calls with loans.
[[Compiler Lower Method Value]] selects the written slots using the
count before reading them. [[Backend Method Programs]] covers a
default that reads an earlier parameter, both directly and as a value.

## Selected indirect callable arity

Architect → Backend Engineer. [[Compiler Lower Default]] owns the
argument profile selector. [[Compiler Lower Lambda]] and [[Compiler
Lower Array Loop]] select the actual closure before projecting
arguments. [[Backend Rendering Callable Programs]] covers held
defaults and named arity failures after argument effects.

## Selected indirect mutable arguments

Architect → Backend Engineer. [[Compiler Lower Loan]] retains each
operand and possible place before [[Compiler Lower Default]] selects
the retained callable's arity and finals. [[Backend Rendering Callable
Programs]] covers default evaluation through an indexed place,
nonexclusive alternatives and the selected missing-parameter diagnostic.

## Mutable finals through ordinary callable types

Architect → Backend Engineer. [[Compiler Lower Lambda]] passes an
already evaluated callee into [[Compiler Lower Loan]] when a retained
layout can carry loan finals. [[Compiler Lower Array Loop]] uses the
selected callback's ordinary result. [[Backend Rendering Callable
Programs]] covers a writable name, a computed value, and an ordinary
tuple with the same native shape.

## Mutable declared receiver selection

Architect → Backend Engineer. [[Compiler Lower Method]] chooses the
held member before collecting loans. [[Compiler Lower Body]] passes
the receiver place through member dispatch. [[Compiler Lower Loan]]
publishes the selected implementation's finals after validating
arity. [[Backend Rendering Callable Programs]] covers ordered indices
and two original destinations.

## Mutable receivers through builtin dispatch

Architect → Backend Engineer. [[Compiler Lower Place]] prepares
the receiver for both declared and builtin member lookup. [[Compiler
Lower Text]] carries the eligible place through nominal fallback.
[[Backend Rendering Callable Programs]] covers a text builtin and
universal conversion selecting mutable implementations.

## Exact writable array indices

Architect → Backend Engineer. [[Compiler Lower Place]] keeps exact
integer keys and validates their representable positions before an
access. [[Backend Rendering Callable Programs]] covers selected wide
and noninteger keys, nested failure order, and writeback.

## Held range keys in bracket reads

Architect → Backend Engineer. [[Compiler Lower Slice]] selects the
bracket operation from the held key. [[Compiler Lower Place]] retains
its read and store forms. [[Backend Rendering Callable Programs]]
covers both directions of scalar and range selection and a loan
whose returned final cannot be assigned through its range.

## Runtime receivers in tuple-checked reads

Architect → Backend Engineer. [[Compiler Lower Slice]] owns
bracket dispatch and the literal slot fast path. [[Backend Rendering
Callable Programs]] covers stable slots and held arrays, text, and
shorter tuples.

## Held destructuring subjects

Architect → Backend Engineer. [[Compiler Lower Tuple]] tests the
retained subject and projects outputs into the enclosing bindings.
[[Backend Rendering Callable Programs]] covers a successful layout
join, a tuple shape mismatch, and a missing field on a held record.

## Held shapes in refutable patterns

Architect → Backend Engineer. [[Compiler Lower Match]] selects held
subjects and skips structurally impossible arms, with runtime kind
diagnostics for sequence bindings. [[Backend Rendering Callable
Programs]] covers guard ordering and a sequence subject mismatch.

## Escaping refutable bindings

Architect → Backend Engineer. [[Compiler Lower Match]] projects
the slots of successful held alternatives into enclosing bindings.
[[Backend Rendering Callable Programs]] exercises a held first
element, a rest binding, and the fallback's outer scope.

## Nested alternative binding layouts

Architect → Backend Engineer. [[Compiler Lower Match]] settles a
shared layout for each capture. [[Compiler Frame Match]] publishes
the capture after the first matching alternative. [[Backend Rendering
Callable Programs]] covers guard and enclosing-scope reads.

## Next action

Preserve shapes and runtime diagnostics for iteration binders when
the held element differs from its checked layout.

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]] · [[CHANGELOG]]
