---
type: module
path: "@root/test/Pudu/Backend/RenderingCallablePrograms.hs"
fidelity: Active
aliases: [Backend Rendering Callable Programs]
---
# Backend Rendering Callable Programs

Export renderingCallableSuccessPrograms (explicit stdout/stderr) and
renderingCallableRefusalPrograms (runtime failures). Cover simultaneously
specialized display/show, identity, primitive/aggregate/callable arguments,
generic calls, records, captures, returned builtin values, source/local
shadowing, entry values, exact depth and owned text reuse. Failure cases cover
operator/key kinds, a source function at the same depth and argument failure.

## Resolved Grill Log

Explicit outputs supplement both evaluator oracles. Every healthy program
also runs under counted allocation wrappers through the shared callable
corpus. Derive depth probes from callDepthLimit. Failures must compare exact
source diagnostics and ordered output rather than accept a native refusal.
Do not infer full builtin coverage from rendering support.

## Dependencies and consumers

[[Backend Output Callable Programs]] · [[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Pudu Test Cabal Manifest]]

## Referenced by

[[Native Rendering Callables]] · [[src/Pudu/Backend/_MOC]]

Export renderingCallableModulePrograms for two provider-owned Token records
with different field types. Resolved Grill Log: complete canonical callable
types must keep these same-spelling specializations separate across modules.
The existing module corpus executes this case in the full gate; focused CLI
checks compare both evaluators and native Clang/GCC/sanitizer builds.

## Stored builtin input layouts (#956)

Resolved Grill Log: render and write differently shaped decoder
results through a stored builtin. A stopping builtin reports at the
indirect call after its argument has run.

## Selected receiver accesses (#956)

Resolved Grill Log: exercise method calls, stored methods and indexing using the held text. A missing method suppresses argument effects. An unsupported index still runs its key.

## Selected invocation arguments (#956)

Resolved Grill Log: matching selected text arguments reach their operation and a wrong held type reports after all supplied argument effects.

## Selected method and primitive inputs

Cover exact selected method operands, later operand effects on
incompatible input, a later control transfer, and text-view reads
and argument failures through both invocation forms.

Resolved Grill Log: success cases assert output and refusal cases
compare effects and the complete runtime diagnostic.

## Wider integer counts and offsets

Cover narrow and wide held integers through direct and stored calls,
huge positive and negative bounds, reversed byte-group shape, and
repeat failure without allocating a large result.

Resolved Grill Log: both orderings of overflowing byte-group bounds
are observed, so clamping before validation cannot pass the fixture.

## Selected numeric keys

Bracket-index coverage distinguishes a wide in-range key, a wide
out-of-range key, and a key whose held value is not an integer.

## Exact slice endpoints

Differential cases cover wider in-bounds endpoints, inclusive upper
bounds, wrong endpoint kinds, and a later expression that transfers
before a lower endpoint can be validated.

Resolved Grill Log: compare output before failure and the complete
diagnostic, including the range span and bounds help.

## Exact stored endpoints

Resolved Grill Log: check storage independently through rendering,
ordering, membership, length, and slicing after the range leaves its
construction site. Include positive, negative and absent endpoints.

## Exact Int identity and operations

Resolved Grill Log: a wide range member sent through a named Int
parameter keeps its value. Check narrowed conversion, wrapping,
signed right shift and the checked Int overflow diagnostic separately.

## Dynamic exact Int payloads

Resolved Grill Log: a wide member selects the Int implementation,
including through a retained method. Compare an exact and narrow
value with equal magnitude and exercise set deduplication.

## Held collection receivers

Resolved Grill Log: exercise an array call held as a map or range,
shared members with different result layouts, and an absent member
whose argument would otherwise print.

## Held collection arguments

Resolved Grill Log: cover wrapped array positions, a foreign-layout
map key, exact positive strides across a huge interval, and the
runtime diagnostics for wrong positions and strides.

## Collection traversal callback failures

Resolved Grill Log: cover empty arrays and ranges with a held
builtin callback, a nonempty invocation failure, and an alternate
non-Boolean result from a callback that has observable effects.

## Held declared method receivers

Resolved Grill Log: a selected declared method can return its
actual callback layout into traversal. The alternate callable's
arity and a missing declared member retain runtime diagnostics.

## Held declared method values

Resolved Grill Log: compare a captured method and a fresh member
read after reassigning the receiver. Exercise a different result
layout, a held function-valued field, and a missing member that
fails before the next statement.

## Selected indirect call defaults

Resolved Grill Log: ordinary indirect calls and traversal choose the
held callable's default count. Distinguish a defaulted one-parameter
closure from a fixed two-parameter closure with the same native slots.
An arity failure retains argument effects and the real parameter name.

## Selected indirect loan defaults

Resolved Grill Log: a selected method with an omitted default writes
back through an indexed place after the index and default each run
once. An alternative with no exclusive parameter retains the same
operand effects and returns without updating the place.

## Hidden exclusive parameters

Resolved Grill Log: a method checked as a value-taking callable
can hold a mutable implementation. A written name is eligible for
writeback and a computed argument is only a value. An ordinary
tuple with the same physical result layout remains an ordinary
result when the selected callable has no exclusive parameter.
Traversal uses only the ordinary result and does not assign finals
to the input array.

## Mutable declared receiver selection

Resolved Grill Log: a checked shared method can select a mutable
implementation, including through an indexed receiver. Its exclusive
arguments and receiver finals update the original places. A missing
selected member stops before argument effects.

## Mutable methods selected from checked builtins

Resolved Grill Log: a checked text builtin can resolve to a
mutable nominal method. Exercise an indexed receiver, its argument
effects, and writeback. An ordinary text receiver still takes the
builtin without a receiver store.

## Exact writable place keys

Resolved Grill Log: exercise exact wide integer keys in assignment,
receiver reads and exclusive arguments. An out-of-range wide key must
never wrap to a valid element. Compare distinct diagnostics for a
noninteger key at a read and a store, and observe replacement effects
before store failure.

## Held range keys

Resolved Grill Log: a checked scalar index can produce a slice and
a checked range can produce a scalar read. Compare array and text
results, receiver dispatch, and an exclusive read whose final cannot
be assigned back through a slice key.

## Held receivers in tuple-checked reads

Resolved Grill Log: compare a stable tuple, a selected array, and
selected text at a written literal position. A shorter held tuple
reports its own bounds failure after receiver effects.

## Selected destructuring subjects

Resolved Grill Log: cover successful bindings across held tuple and
record layouts. Shape failures report the whole pattern and subject
kind after evaluation and before later statements run.

## Held shapes in refutable patterns

Resolved Grill Log: exercise a sequence arm and guard on its matching
layout, fall through on a different layout, and preserve a sequence
binding diagnostic when its subject has the wrong shape.
