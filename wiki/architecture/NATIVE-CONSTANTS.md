---
type: architecture
status: IMPLEMENTED
tags: [architecture, backend, constants]
aliases: [Native Folded Constants]
---
# Native Folded Constants

A module constant is the value the compiler already folded with effects denied.
Native lowering consumes that same immutable product from CompileResult;
it never evaluates an initializer, repeats a comptime call, or reads source
spelling to reconstruct an answer. [[Native Emission Coverage]] remains the
full completion contract.

## Data and name boundary

NativeModule carries each module's compileFolded map beside its checked syntax
and solved facts. ModuleScope records every declared constant, with its frozen
value when available. A declared constant lacking a portable product is a
located E6001 refusal when reached, not a request to run its initializer.

Locals resolve first. A module's own constant or a selectively imported one
resolves unqualified; aliases and module qualifiers resolve only constants
actually declared by the selected module. An import never re-exports another
module's constant implicitly. Function and variant dispatch retain their
existing order after constant lookup has declined the name.

## Representation boundary

[[Compiler Lower Constant]] projects the thawed plain data against the settled
Core type at the complete reference span. Existing Core carriers preserve
integer kind and exact magnitude, raw Float32/Float64 bits, text, Char, Bool,
unit, tuples, declaration-ordered records and sum tags with ordered payloads,
arrays, maps, sets and range values.
Canonical checked types choose aggregate identity and layout; a display name
never selects another module's representation. Owned values use the ordinary
frame/refcount paths, including repeated reads and transfers.

BigInt, Decimal and bytes use their existing literal carriers. Frozen
collections project each nested value at its checked type (#808); map/set
construction starts from stored ascending entries and preserves their held
representatives. Range endpoint presence and inclusivity remain explicit.
No native runtime ABI change is required for these carriers. Buckets/null
and callable/resource constants still require their own carrier or portable
product contracts; this does not complete the broad constants area.

Resolved Grill Log (#808): a malformed nested element or unrepresentable
range endpoint refuses at the constant use. No initializer is rerun and no
runtime resource or closure is manufactured from frozen display data.
[[Native Frozen Collection Delivery]] owns the continuation and evidence.

## Validation

Use real compiled products, including imported constants, aliases, prior
constants and comptime calls. Compare tree and compiled interpreters with
native output, status and diagnostics. Lock hand-written answers for wide
integers, floating bits/-zero/NaN, text and nested aggregate constants. Cover
same-spelling constants and types in separate modules, transitive imports,
missing folded products and unsupported constant kinds. Compile-time errors
remain compile-time errors. Run Clang, GCC, sanitizers, counted allocation
cleanup and full repository gates.

## Resolved Grill Log

- Re-running an initializer is rejected: the compiler already owns folding,
  effect denial and compile-time diagnostics.
- Name spelling alone cannot select a constant's type or aggregate layout;
  use exact solved expression facts and canonical shapes.
- Pure single-module lowering cannot fabricate compiler products. Provide a
  folded-aware entry for CompileResult consumers and retain an explicit
  refusal when a declared constant has no supplied folded value.
- A frozen value owns no external handle or captured environment; do not
  manufacture a runtime resource or function from its printed form.

## Referenced by

[[Native Emission Coverage]] · [[Compiler Lower Constant]]

## Delivery evidence (#543)

All 20 clean repository gates pass, including actual optimized compilation of
339 production modules, 143 test modules and 712 named test groups. Focused
Clang, GCC 15, ASan/UBSan and both interpreter-mode comparisons pass; 71 counted
programs release every allocation. A real CLI native build of imported
constants and same-spelling aggregate types matches both interpreters exactly.
Unsupported folded families above remain explicit full-emission obligations.
