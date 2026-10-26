---
type: module
path: "@root/src/Pudu/Backend/Runtime/Integer.hs"
fidelity: Active
aliases: [Backend Runtime Integer]
grammar: "[[grammar/haskell]]"
---
# Backend Runtime Integer

The prerequisite catalogue also closes fail -> cleanup and memory_failure ->
cleanup for #499. Resolved Grill Log: every existing checked helper retains its
renderer dependency, including isolated runtime selection tests.

## Purpose and interface

Export integerRuntimeParts :: [(Text, [Text])] and
integerRuntimeDependencies :: Text -> [Text]. Concatenate value, arithmetic and
bit catalogues in dependency order for [[Backend Runtime]]. The pure fixed
prerequisite table lets [[Backend Emit Support]] select a transitive closure
without emitting unused static functions. Root print_int explicitly depends on magnitude; other unknown noninteger/root
part names have no integer-specific dependencies. No IO or new dependency.

## Algorithm and invariants

[[Backend Integer Value]] owns the exact sign/magnitude ABI declarations,
normalization, bit conversion, width masks and mathematical comparison.
[[Backend Integer Arithmetic]] owns unsigned mathematical kernels and checked,
saturating, division/remainder and negation policies. [[Backend Integer Bits]]
owns wrapping, bitwise and checked-count shift operations.

Every selected function's prerequisite precedes it in the catalogue. Arithmetic
settlement retains overflow sign until the declared bound policy is applied.
Bit conversion decodes the declared kind, while comparison reads mathematical
values before wrapping. Negative and oversized shifts retain distinct failure
sites. [[Exact Native Integer Carriers]] specifies the complete algorithms and
phase contract. The current runtime revision is 7; an internal carrier is not a public
Pudu type-width/FFI layout promise.

## Resolved Grill Log

- **Q:** Retain the old int64_t representation for a deferred positive boundary? **A:** No; unsigned magnitude and sign preserve it exactly.
- **Q:** Add all helpers to every program? **A:** No; a fixed prerequisite graph and visited set select only required functions in deterministic order.
- **Q:** Does helper support admit every numeric kind? **A:** No; lowering still owns canonical type admission and rejects unrepresented kinds. Full native coverage remains open.

## Dependencies and consumers

[[Backend Integer Value]] · [[Backend Integer Arithmetic]] · [[Backend Integer Bits]] ·
[[Backend Runtime]] · [[Backend Emit Support]] · [[Exact Native Integer Carriers]]

## Conversion (#560)

[[Native Integer Conversion]] joins the integer parts after the wide ones it
uses.

## Referenced by

[[src/_MOC]] · [[Native Emission Coverage]] · [[Native C11 Backend Delivery]]

## Wide runtime selection (#504)

Append Word128, Wide.Value, Wide.Operations and Wide.Display catalogues after
narrow integer parts; combine their explicit dependency functions with the old
scalar table. fail now owns site/colored/cleanup. Resolved Grill Log: real
minimal runtime roots must compile without stubs, omitted prerequisites or
unused static functions; no source admission or existing frame ABI change.

## Fatal IO dependency (#505)

fail and memory_failure also own error_io and process_io, including the
post-diagnostic restoration needed for exit-time stdout flushing. Resolved Grill Log: real minimal
roots must include fatal-signal preparation without an unused startup helper.
