---
type: module
path: "@root/src/Pudu/Backend/Emit/Kernel.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Emit Kernel]
---
# Backend Emit Kernel

Export frameKernel. Each kernel name maps to one runtime function and the
part that defines it. The call passes the operand cells in order, then the
kernel's integers. `KernelPresent` is a null test on the held box. The
flat-table kernels also pass the tree operations of the control store and
the slot store, named from the table's value type.

## Resolved Grill Log

The table is total over CoreKernelName, so a new kernel cannot be emitted
without a runtime function. Operand and result carriers are those the frame
already holds; nothing is converted here.

## Referenced by

[[Backend Frame Values]] · [[Native Builtin Kernels]]
