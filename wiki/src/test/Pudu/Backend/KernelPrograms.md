---
type: module
path: "@root/test/Pudu/Backend/KernelPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Kernel Programs]
---
# Backend Kernel Programs

Export kernelSuccessPrograms, kernelLibraryPrograms and kernelRefusalPrograms.
Success programs carry handwritten output for the buffer, column and
flat-table primitives, the checksums, the audio generators and every
builtin as a value. Module programs import `Std.FlatMap`, `Std.Json`,
`Std.Xml` and `Std.Csv`. Refusal programs pin each reachable E7004 and
E7001 with its span, directly and through a value.

The flat-table and codec refusal cases are built from [[Backend Kernel Counted Programs]] bodies plus their refusing tail. `kernelLibraryPrograms` now also runs under the counted-allocation harness, so the completing bodies are checked for live allocations at exit.

## Resolved Grill Log

Expected output is written by hand or from published vectors, never copied
from a native run. The corpus joins the existing differential and
counted-allocation harnesses. Float projections and additions in differential
byte tests use deterministic finite floats so byte representations remain
portable across ARM64 and x86_64 architectures, while NaN arithmetic and
filtering semantics remain verified through dedicated aggregate and filter tests.

The broad phase answers touching pairs (signed zero included) in order and refuses a NaN bound, unequal counts and an inverted box; an empty array compares with an array whose element a generic solved, on either side (#846). That case imports `Std.Iter`, so it sits in `kernelLibraryPrograms`, which the conformance property runs and the single-module leak harness does not.

The raster kernels fill (clamped and half-even channels), cull, own shared edges, interpolate affinely and with perspective weights, sample nearest and bilinear in linear and sRGB with alpha cutout, and shade; every malformed target, cull, lane count, weight, texture and uniform answers None (#855).

## Binary codec (#935)

The library programs check canonical scalar wire bytes, recursive values,
map construction, and corrupt input. The refusal program checks duplicate
writer fields through a first-class builtin, including caller blame.

## Referenced by

[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Backend Module Programs]] · [[Native Builtin Kernels]]
