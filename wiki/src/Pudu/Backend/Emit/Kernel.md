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

## Host kernels (#846)

`KernelHost host` emits `pudu_host_<host>`, `KernelHostState` emits
`pudu_host_state` and `KernelHostMessage` emits `pudu_host_message`. A kernel
that releases a held operand (`cell_open`, `cell_swap`, `channel_push`,
`thread_spawn`, `scope_adopt`, `scope_stash`) also names the drop helper of
that operand's type; one that answers held data (`cell_get`, `channel_pull`,
`channel_pull_within`, `scope_stashed`) names the drop helper of its value.
Resolved Grill Log: the box is released as its own type through the standard
drop helper, so the host never guesses a carrier.
