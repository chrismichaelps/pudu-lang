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

Typed direct entries from [[Backend Typed Integer Calls]] are emitted before
the stack entries that call them. The function table keeps the usual frame
body, and the stack entry selects the typed form only for canonical inputs.

Resolved Grill Log: compacted entry functions with at most 32 cells and no
frame calls get fixed startup storage. All other entries continue through
the ordinary dispatcher. Pass the actual compacted cell bound to the runtime.

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

## Bytes (#565)

Bytes need the text cell, since their box holds a text view; an entry
returning Bytes renders it; [[Native Bytes Runtime]] is emitted after the
frame types.

## Foreign wrappers (#850)

The wrappers of every foreign declaration the frames call follow the aggregate helpers and precede the function bodies.

## Foreign handles (#853)

The C entry installs the process cleanup hook when foreign handle support is
selected. A handle entry result uses the aggregate reporting path. Teardown
releases the foreign claim first, then reporting uses the address retained in
the box without dereferencing it.

## Foreign needs (#852)

The module adds the needs of its foreign declarations (record constructors, releases, leaf conversions) to the aggregate and runtime selection, and passes its layouts to the wrappers.

## Direct set (#904)

The program asks [[Backend Frame Direct]] for the direct set, passes it to the bodies and
the exports, and after the frame engine emits, for each direct function,
`static pudu_cell pudu_direct_<n>(const pudu_cell *arguments)`: a frame and cell array on the
C stack, where only owned slots of the cell array are zeroed; the frame header is set field by
field in `pudu_stack_enter`, then `pudu_run_<n>`, `pudu_stack_leave`, then return the result. `argumentCount` now comes from [[Backend Frame Direct]].

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

## Entry output reporting (#566)

Resolved Grill Log: Route all rendered noninteger/nonunit entry values through pudu_output_report. Rendered text and the original owned entry value are released after reporting; return the report status. Select text renderers and output_report instead of the legacy scalar printer for these entry paths.

## Named callable dispatch (#568)

Resolved Grill Log: Append explicit environment metadata from frameModuleClosures to each function descriptor; nonclosure/direct named functions have no hidden environment.

## First-class output builtins (#569)

Resolved Grill Log: Emit counted=0 only for builtin intrinsic bodies, otherwise 1, independently of hidden environment metadata.

## Caller-blaming functions (#644)

pudu_function gains `blames`, set for method closures; method closures are
not counted toward call depth, like builtins. Resolved Grill Log: the flag is
what lets the reporter relocate any failure inside them.

## Blame hook part (#791)

The frame base parts include `blame`, which frame entry and exit assign.

## BigInt (#800)

A program holding a BigInt anywhere gets the `big` cell member and the carrier's value, retain and release parts. The drop and retain switches release and retain every owned kind by its own code, BigInt's included; an entry BigInt is released after its exit status is read.

## Decimal (#802)

A program holding Decimal gets the `decimal` member, its value, retain and release parts, an ownership code, and an entry that prints and releases its Decimal.

## Indexed stores (#840)

A store entry renders through its show helper. The hash parts join the post-frame runtime parts. A builtin taken as a value, like a method value, neither counts depth nor keeps its own failure site: `blames` is set for both. Resolved Grill Log: the interpreter reports a builtin's failure at the call made through it; explicit caller failures were already there, and sited arithmetic inside a builtin body now agrees.

## Threads, arguments and active runs (#846)

`frameEngine` takes whether the program starts a thread and whether it reads
its arguments. With threads, the active frame and its depth are
`_Thread_local`, and `pudu_run_closure` starts a lifted closure at the depth
its thread was created from. `pudu_run_frames` now installs the hooks, calls
`pudu_run_active` and clears the hooks; a started thread's failure ends that
thread rather than the program, through the runtime's trap hook.

A program that reads its arguments is entered as
`int main(int count, char **values)` and stores the vector in the host runtime
before preparing I/O; every other program keeps `int main(void)`.

Resolved Grill Log: thread state is per-thread and the hooks are per-run; the
entry shape is chosen only when the argument kernel is selected, so no program
pays for a parameter it cannot read.

## Byte data tables (#887)

The program writes the registered byte-literal tables right after the site
table, before any function that reads them.

## Entry forms (#878)

Export `emitFrameUnit :: EntryForm -> Text -> [Source] -> FrameModule ->
Either FrameFault EmittedUnit`; `emitFrameProgram` is its executable form's
source. The entry's opening and closing come from [[Backend Emit Entry]]
(`entrySection`), told whether `host_arguments` and `output_state` are
selected. The unit carries the selected part set and the libraries of the
frames' foreign declarations with their optional versions in first-seen order. Resolved Grill Log: the
desktop unit's bytes are unchanged; only the embedded form wraps the body.

## Exported functions (#899)

The embedded form appends [[Backend Emit Export]]'s wrappers after the entry
and adds their conversion needs to the runtime selection; the prototypes are
reported in the emitted unit. The executable form emits none.

## Physical slot allocation (#821)

[[Backend Frame Slots]] runs before runtime selection, direct eligibility and
body emission. Layout metadata and every emitted reference use the same
physical slot IDs. The logical frame remains available to lowering tests.
Resolved Grill Log: one layout for every backend consumer.

## Resolved Grill Log for Objective-C delegates

Delegate definitions are emitted after the foreign wrappers and before the frame bodies that construct delegates, so each constructor is declared before its first use.

## Callback entry results (#956)

Run the entry once and report its callback token using [[Backend Emit Cell]]'s
shared token text renderer.

### Resolved Grill Log

Direct reporting and rendering from a cell share one canonical owner spelling.

## Exact range cells

Resolved Grill Log: range layouts require the exact integer cell even
when no source function itself declares an exact integer.

## Kept constants (#999)

- The program renders the registered constant cells and ready flags at file scope, beside the byte tables and before any function that reads them.

Resolved Grill Log (#999): **Q:** Why file scope instead of function-local storage? **A:** A kept value must outlive a single frame and be shared by every function that reads it. _Rejected:_ static locals per function, which would hold one copy per reader.

Each kept cell holds its reference until the program ends. The first keep registers `pudu_constants_release` with `atexit` once, through `pudu_constants_arrange`, and that function releases every built cell by its type, so a kept value is never counted as memory the program lost and the allocation-balance tests stay exact. `emitConstants` records each cell's name and type, and `FrameConstantReady` carries the constant's type, so whichever read registers a cell first records the type its release needs. `constantRelease` in `Backend/Emit/Frame.hs` is rendered after the aggregate helpers because it calls their drop helpers. The full property suite passes 903 of 903.
