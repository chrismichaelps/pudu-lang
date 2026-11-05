---
type: module
path: "@root/lib/Std/Iter/Views.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
aliases: [Std Iter Views]
tags: [module, stdlib, iteration]
---
# Std Iter Views

## Purpose and interface
Optional restartable Sequence adapters: chunk(source,width), slide(source,width),
chunkBy(source,adjacent), join(source), reverse(source), cartesian(left,right).
Export their named wrapper types Chunked, Sliding, Grouped, Joined, Reversed, Product.
Compose with Sequence.through and ordinary map; keys/values, adjacent transforms,
zip transforms and flat-map need no new protocol members.

## Algorithms and contracts
Constructors retain values without walking. chunk yields disjoint Arrays, including a
partial last chunk. slide yields only complete overlapping Arrays. Widths below one
clamp to one, matching stride. Grouped compares adjacent original items and carries
one lookahead item; singleton/empty groups behave naturally. Window storage is
bounded by width (chunkBy by group length); input items are not re-evaluated.
Joined walks nested Sequences while retaining outer and current inner states; empty
inner sequences are skipped without materializing the outer source. Reverse buffers
a finite input on the first requested advance, then walks backwards; it is deliberately
not a constant-space bidirectional C++ view. Product restarts the right Sequence for
each left item and yields lexicographically ordered pairs without staging either side.
Each adapter is restartable, bounded-prefix consumption must avoid later source work,
and adapters do not ask an exhausted source again during that walk. Both sides of Product must be finite for full
collection. Sequence sources themselves must obey their restartability contract.

## Resolved Grill Log
Use a separate optional module to avoid growing the large protocol or creating an
import cycle. Keep state in ordinary values. No public iterator categories, pointer
ABI or borrowed mutable references. Infinite inputs require a bounded terminal;
reverse requires a finite input. Defer delimiter/pattern splitting and joinWith to
separate specifications rather than silently guess equality and empty-pattern semantics.
No new compiler syntax, runtime builtin or allocation policy is required.

## Dependencies and consumers
[[Std Iter]] · [[C++ Inspired View Coverage]] · [[UsesIterViews]]

## Referenced by
[[src/Std/_MOC]] · [[Std Views Delivery]]
