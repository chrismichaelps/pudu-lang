---
type: architecture
aliases: [Native Wide Frame Bridge]
tags: [native, numeric, architecture]
---
# Native Wide Frame Bridge

## Contract

Integrate the portable wide runtime with actual checked Core/frame emission.
Keep frontend native-kind admission unchanged until the following source matrix
slice proves Int128/UInt128 through both evaluators and real CLI executables.
This bridge changes the private frame ABI and runtime revision to 7.

Backend Emit.Support owns isWideInteger :: IntegerKind -> Bool (width 128)
and integerHelper :: CoreType -> Text -> Text (wide_ prefix for wide integers).
Spell wide literals as two uint64_t words of the mathematical value modulo
2^128 plus independent actual-negative flag. Select pudu_wide_kind for width
128 descriptors, pudu_wide_int for declarations/results and a typed wide zero.
Keep old narrow representations unchanged. Legacy Core runtimeNeeds must use
the same typed helper/printer/status names and include wide type declarations;
no stale helper-selection API is left behind.

Frame.Value selects wide cell members and operations from canonical result
kind; comparisons instead select from their integer operand kind because the
result is Bool. Return selected helper roots with exactly the called names.
Frame.Body uses wide_print_int for wide print slots. Frame assembly uses
wide_status and the wide result member for a wide entry; unit/Never behavior
stays unchanged. frameUsesWideCells :: FrameModule -> Bool checks all function
results/parameters/slots, not only helper roots, so literal-only or dead-result
wide payloads still get their ABI declarations. frameTypes :: Bool -> [Text]
adds a wide member only for wide programs. Old narrow-only cells retain their
layout, checked allocation and frame lifetime policy; no C recursion is added.

## Evidence and ownership

Backend Engineer owns Runtime revision, Runtime.Frame, Emit.Support,
Emit.Frame, Emit.Frame.Value and Emit.Frame.Body plus mirrors. Test Engineer
owns WideFrameSpec and FrameEmitSpec updates, registration and mirrors. Reuse
production frameTypes in the strict body harness and replace its unsupported
128-bit manual descriptor with unsupported 256-bit metadata.

Construct valid typed Core IR and run actual lowerFrames/emitProgram plus
strict C11 compilation/execution. Prove both wide kinds, full-width extrema,
deferred positive 2^127, mixed narrow/unit/wide frame cells, call argument
snapshots, returns, comparisons with Bool results, literal-only wide/unit
entries, decimal output and status. Count actual frame allocations/frees on
normal and runtime-error exits; ASan/UBSan supplement that evidence. Check
narrow-only layout and emitted narrow behavior remain unchanged, actual helper
closures compile without unused functions, and all full gates pass. Source
admission and full language parity remain pending until the next delivery.

## Resolved Grill Log

- **Q:** Select wide comparison from its Bool result? **A:** No; use its integer operand kind.
- **Q:** Infer wide frame layout from called helpers? **A:** No; inspect every declared slot/parameter/result, including literal-only paths.
- **Q:** Enlarge old narrow-only frame cells? **A:** No; the optional wide member is emitted only when needed.
- **Q:** Narrow the positive deferred boundary on a call/return? **A:** No; copy both words and actual sign unchanged.
- **Q:** Admit source types before this backend is tested? **A:** No; preserve the fail-closed frontend predicate until full source differential tests.

## Dependencies and consumers

[[Native Wide Runtime Integration]] · [[Backend Frame Program]] · [[Backend Frame Runtime]] · [[Backend Frame Values]] · [[Backend Frame Bodies]] · [[Backend Emit Support]] · [[Native Wide Frame Tests]]

## Referenced by

[[architecture/_MOC]] · [[Native Wide Frame Delivery]]
