---
type: module
path: "@root/src/Pudu/Backend/Emit/Frame.hs"
fidelity: Active
aliases: [Backend Frame Program]
---
# Backend Frame Program

## Purpose and interface

Export emitFrameProgram :: Text -> [Source] -> FrameModule -> Either FrameFault Text.
Assemble selected runtime, frame types, sites, generated bodies, parameter-index
arrays/descriptors, frame engine and C main in deterministic order. Close runtime
dependencies from emitted roots only, with the frame engine's required host-failure
and cleanup parts. Select status only for an integer entry. Unit/Never entry
discards the returned cell and exits zero on normal completion. Entry must exist
and have no parameters. Numeric IDs follow module order. Empty parameter vectors
use NULL, not zero-length arrays. Frame slot counts and argument scratch maxima
come from actual emitted functions. No frontend/compiler import or inference.

## Resolved Grill Log

- **Q:** Lower structured Core inside the backend? **A:** No; the compiler calls lowerFrames before this boundary.
- **Q:** Emit unused recursive wrappers too? **A:** No; only step bodies and descriptors are emitted.
- **Q:** Hide a failed emission as C text? **A:** No; return FrameFault data.

## Dependencies and consumers

[[Core Frame IR]] · [[Backend Frame Bodies]] · [[Backend Frame Runtime]] · [[Backend Runtime]] · [[Backend Emit]]

## Grill Log

- **Q:** Which runtime parts does a sum pull in? **A:** Its own helpers and those of every type its layout reaches; showing a sum also needs text printing (#525).

## Generic records (#552)

Pattern update only: `CoreRecordType` has an argument list.

## Closures (#555)

Resolved Grill Log: closure helpers learn each function's frame-table number.
An entry returning a function prints `<fn name>`, and argument space counts a
call through a value's closure.

## Arrays (#556)

Resolved Grill Log: the array runtime parts are written after the frame types;
an entry returning an array prints it; text inside an array counts as text
use.

## Text pieces (#559)

[[Native Text Pieces]] is emitted with the array runtime, after the frame
types, because it builds arrays.

## Maps and sets (#561)

An entry returning a map or set renders it. [[Native Persistent Trees]] is
emitted after the frame types, with the array runtime.

## Range values (#564)

An entry returning a range renders it; [[Native Range Runtime]] is emitted
after the frame types.

## Referenced by

[[src/_MOC]] · [[Native Frame Pressure Repair]]

## Closed-pipe startup (#505)

Select process_io and call pudu_prepare_io at the start of C main, before frame
allocation for every entry-result kind. Resolved Grill Log: startup policy must
not depend on whether entry returns Int, unit or Never, and must preserve later
source execution after ignored print errors. [[Native Closed Pipe Semantics]].

## Wide frame bridge (#506)

Export frameUsesWideCells :: FrameModule -> Bool, inspecting every function result, parameter and slot type. Include wide_value and pass that flag to frameTypes when needed. Wide entry results select wide_status and the wide member; startup policy remains unchanged. Resolved Grill Log: literal-only and unused-wide slots still require ABI types, while narrow programs retain their layout. [[Native Wide Frame Bridge]].

## General runtime prerequisites (#511)

Use [[Native Runtime Dependencies]] in the existing visited-set traversal.
Frame layout, entry behavior and selected roots remain unchanged. Resolved Grill
Log: share the production dependency contract without premature float admission.

## Rendered entry results (#512)

A Bool entry prints `true`/`false` with a newline and returns 0; a float entry
prints through `pudu_print_float` and returns 0. Both mirror `reportResult`,
including its silence when stdout is a closed pipe. Floating cells select
`float_target` with their arithmetic helpers only.

## Text frames (#515)

Each function's metadata lists its text slots and whether its result is text,
so the engine can retain arguments, release slots when a frame ends, and hand
a returned text to its destination. A Str entry result is shown, printed and
released before `main` returns 0. The text runtime and the cell's text member
are selected only when some slot holds text.

## Char entry results (#518)

A Char entry is shown through `pudu_char_show`, printed and released, and
returns 0, matching `reportResult`.

## Owned slots (#521)

Metadata lists every owned slot with its kind (`pudu_owned`), and
`result_kind` replaces the text-result flag. `ownershipSwitch` writes
`pudu_drop_cell` and `pudu_retain_cell` over the kinds present. The cell's
text and wide members are selected when a slot holds the type directly or
inside a tuple. A tuple entry result is shown, printed, and both references
released.

## Record entry results (#521)

A record entry is shown, printed and released like a tuple entry.
