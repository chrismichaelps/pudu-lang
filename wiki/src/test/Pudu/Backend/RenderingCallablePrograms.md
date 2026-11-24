---
type: module
path: "@root/test/Pudu/Backend/RenderingCallablePrograms.hs"
fidelity: Active
aliases: [Backend Rendering Callable Programs]
---
# Backend Rendering Callable Programs

## Held member reads

Resolved Grill Log. Read a held named payload and render a declared
method selected where a field was checked. Verify missing-member
diagnostics after receiver effects.

## Concrete held aggregate construction

Resolved Grill Log. Construct records, updates, arrays, sets and
maps from a concrete held character through Bool-checked fields.
Include a mixed key layout, duplicate keys and ordered field effects.

## Held record updates

Resolved Grill Log. An update on a different held record keeps
that record's identity, replaces fields it has, and evaluates
absent-field initializers. A non-record base reports after
replacement effects and preserves an earlier operand transfer.

## Concrete held writes

Resolved Grill Log. Write a held character through a Bool-checked
local, record field and indexed slot. Assert index order, the
resulting value layouts, and the original held aliases.

## Concrete held call arguments

Resolved Grill Log. Iterate text through a Bool-checked binder and
call a named function, stored function, captured lambda, positional
constructor and loaned callable with the held character.

## Concrete held sum payloads

Resolved Grill Log. Iterate a held text source through a Bool-checked
binder. Store the held character in both positional and named nested
payloads. Verify the Boolean literal does not match and a binding
retains the character. [[Compiler Lower Sum]]

## Held runtime conditions

Resolved Grill Log. Compare reached and skipped operands of both
logical operators. Cover condition diagnostics from if and while,
and verify a non-Bool guard runs its effects before falling through.

## Held loop results

Resolved Grill Log. Exercise both exits from a loop with mixed held
break layouts. Include a labelled outer break through an inner
loop, a bare break carrying unit, and effects in a valued operand.

## Held branch result layouts

Resolved Grill Log. Return different held layouts through if and
match arms. Render each selected value and inspect the ordered
effects to detect premature or repeated arm evaluation.

## Held iteration sources

Resolved Grill Log. Cover a tuple with different held item layouts,
a checked tuple binder presented with arrays, and a noniterable scalar.
Assert iteration order, binder skips, and a diagnostic after the source
effects. [[Compiler Lower For]]

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

## Escaping refutable bindings

Resolved Grill Log: use a binding after two successful held layouts
and exercise a failing alternative that runs the fallback without
publishing a value.

## Nested alternate binding layouts

Resolved Grill Log: use an alternate capture with two held layouts
in a guard and body. A rejected guard proceeds to the following arm.

## Canonical pattern owners

Resolved Grill Log. Use two modules with identical record and variant
spellings. Check both the declared module's values and the other module's
held values for named records, positional variants, and named variants.
[[Compiler Lower Match]]

## Anonymous record patterns over named sum payloads

Resolved Grill Log. Iterate selected named, positional, and missing-field
variants through a record-checked binder. Compare ordered output for
different successful field carriers, guard execution only after match,
and fallthrough. A nested sequence binding must also preserve the held
sum diagnostic for a variant missing the field. [[Compiler Lower Match]]

## Retained builtin members

Resolved Grill Log. Render a field-checked member that holds a builtin,
invoke a held builtin with a different result carrier, and keep the
selected receiver through later assignment. Check absent members and
caller-site diagnostics separately.

Resolved Grill Log: capture open map and reduce members through scalar
fields in a checked record. Render the open values and invoke returned
captures through a checked callable with concrete callback and seed types.
Use a retained map as the callback over nonempty and empty inputs.
Compare the open map with concrete maps on equal and unequal receivers.
Compare bound traversals on empty arrays with distinct element layouts.

Resolved Grill Log. Compare bound map, set, and bucket methods in a shared
callable slot. Empty receivers compare across element layouts. A different
family, member, or receiver entry makes the comparison unequal.
