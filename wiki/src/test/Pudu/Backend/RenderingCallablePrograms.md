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
