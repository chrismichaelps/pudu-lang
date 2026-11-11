---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Compiler/Lower/Kernel/Lanes.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Kernel Lanes]
---
# Compiler Lower Kernel Lanes

Export lanePrimitives: the packed binary64 lane kernels. Each signature is
read from the one list the checker reads, so a kernel's operands are written
once. Byte operands are checked for whole lanes after every operand has run,
as the interpreter checks them.

## Resolved Grill Log

The lane list is shared with checking so the two cannot drift. A kernel whose
operands lie outside what it takes answers None through the host state.

## Referenced by

[[Compiler Lower Kernel]] · [[Native Host Lanes]] · [[Native Host Services]]
