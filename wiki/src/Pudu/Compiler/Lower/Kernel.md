---
type: module
path: "@root/src/Pudu/Compiler/Lower/Kernel.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Kernel]
---
# Compiler Lower Kernel

Export lowerKernelPrimitive, kernelCallable and kernelPrimitive. One table
gives every monomorphic kernel builtin its parameter types, result type,
guards and answer. Arguments lower once in source order into held locals; a
Never argument ends the call before later ones run. Guards run in the
interpreter's order and stop with its code and message. An answer is a plain
kernel value, `Some` of a read when a test holds, `Some` of a found index,
`Some` of a present box, or the byte length.

The JSON and XML entries exist only when the program's `Std.Json.Json`,
`Std.Xml.Tag` and `Std.Xml.Node` layouts have exactly the shapes the runtime
builds; their variant indexes and field positions become the kernel's
integers.

## Resolved Grill Log

Direct calls and callable bodies share one builder, so they cannot drift. A
guard blames the call, or the call made through a value of the builtin.
Option results are built in Core from a test and a read, so the runtime
never names a sum's layout except where a codec builds a whole tree.
Rejected: one lowering function per builtin.

Resolved Grill Log: `urlEncodeComponent` (issue #1007) is a fixed primitive, so direct calls and callable bodies share its guard and blame.

## Binary codec (#935)

The binary entries require the checked `Std.Binary.Node` variants and
payloads. The writer uses a required box answer with E7001 when absent.
The reader uses the host outcome channel to construct `Result[Node, Str]`.
Direct calls and builtin values share those paths.

## Referenced by

[[Compiler Lower Primitive]] · [[Compiler Lower Intrinsic]] · [[Native Builtin Kernels]]

## Host, lanes and shape (#846)

The kernel's host primitives are split into [[Compiler Lower Kernel Host]]
(the binary64 math, clocks, process surroundings, files and handles),
[[Compiler Lower Kernel Lanes]] (the packed binary64 lanes) and
[[Compiler Lower Kernel Shape]] (the shared primitive and answer types).
`KernelHost` answers direct calls through the same validated signature
machinery as the other kernels. Resolved Grill Log: the split keeps each
module focused; no host name is claimed by another family.

Resolved Grill Log: `htmlRender` resolves the program's own `Std.Html.Html` layout; a page type with other variants is not lowered.

## httpHeaderPairs (#1021)

`httpHeaderPairs` is a fixed primitive with one `Str` parameter and the answer `Array[(Str, Str)]`, lowered through `KernelHttpHeaders`.

Resolved Grill Log: a direct call and a callable value share one guard and blame, as `urlEncodeComponent` does.
