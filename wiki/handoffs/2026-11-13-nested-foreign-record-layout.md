---
type: handoff
status: ACTIVE
issue: 863
aliases: [Nested Foreign Record Delivery]
---

# Nested Foreign Record Delivery

Language Architect → Runtime Engineer. The interpreter bridge owns record
descriptions, storage, and leaf offsets. The checked crossing still owns
the field order and the per-record member limit. The C11 emitter already
uses nested structs.

## Resolved Grill Log

- Send a recursive record description alongside the existing flat leaf
  carriers. Build one libffi struct per record node. Add child offsets to
  its parent offset when mapping back to the flat carriers.
- Bound each record's direct member count by the checked limit. Allocate
  leaf offsets and record buffers for the actual validated signature.
- Keep all descriptions and storage alive through argument preparation,
  dispatch, and result decoding. Release them on every bridge exit.

## Validation

The focused foreign groups and direct slot check pass on macOS. The nested
fixture checks eleven values, including a padded argument and result, a
padded output slot, and a result with 36 scalar leaves.

## Exact next action

Record optimized CI results and independent ABI review on the pull request.

## Referenced by

[[handoffs/_MOC]] · [[Foreign Call]] · [[Pudu FFI Bridge]]
