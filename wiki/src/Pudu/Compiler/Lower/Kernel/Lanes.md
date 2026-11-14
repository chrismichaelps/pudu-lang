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

## Broad phase (#846)

`lanesOverlapPairs` maps to `lanes_overlap_pairs`. Only the raster kernels keep
no native part.

## Raster kernels (#855)

`rasterFill` and the four triangle kernels map to the parts of
[[Native Host Raster]], so every lane kernel has a native part and `lanePart`
is total. `byteTargets` names the byte operands that are RGBA targets or
texels (the color target of every triangle kernel, and the texels of the
textured one); they are not guarded as whole lanes, as the interpreter does
not check them.

Resolved Grill Log: skip exactly the interpreter's unchecked positions rather
than guard every byte operand. _Rationale:_ an RGBA target of an odd pixel
count is a valid target, and a guard there would refuse a call the interpreter
draws.

## Referenced by

[[Compiler Lower Kernel]] · [[Native Host Lanes]] · [[Native Host Services]]
