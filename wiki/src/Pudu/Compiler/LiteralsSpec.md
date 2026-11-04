---
type: module
path: "@root/test/Pudu/Compiler/LiteralsSpec.hs"
fidelity: Active
domain: "[[Compiler Pipeline]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, performance, lowering]
aliases: [Compiler Literals Spec]
---
# Compiler Literals Spec

Compiles one module through `runCompile` and reads both trees. In `compileModule`, `0xFF` is
`ResolvedInteger PlatformSigned 255`, and the `1` in `x + 1` and the `2` passed as an argument are
`ResolvedInteger (UnsignedKind 8)`, the kind checking gave them from `UInt8`; no `IntegerValue` text
remains. In `compileSyntax` the same literals keep their source text, in order.

The product cache's own property ([[Cache Persist]]) now includes an unbounded integer read back
digit for digit, since a stored module carries resolved values.

See [[Compiler Literals]].

## Grill Log

Resolved Grill Log: the kind is asserted where the checker chose it rather than the default, because
that is the case a wrong resolution would get wrong silently.

## Complete implementation heads (#735)

ImplementationOwner Type is a distinct owner fact for an implementation target.
Form its complete target with implementation rigid parameters, transparent aliases
and canonical nested nominal identities. Env publishes this local immutable fact
separately from provider evidence and interface snapshots. Compiler Literals reads
it only at the structural Impl target field and projects the complete formed type
into executable syntax; source/tooling syntax remains authored. Expression and
pattern projections ignore this role. Preserve source spans, declared parameter
order and the static-selection map; do not infer parameters from runtime values.

Resolved Grill Log: a later runtime matcher needs Pair[Array[B], A] from an alias
Reversed[A, Array[B]], not the authored alias arguments zipped to A/B. Keeping the
complete checked target is a prerequisite, not the #735 dispatch repair itself.
A focused compiler property must assert canonical executable heads, retained
source heads and unchanged target spans. Existing static and derive regressions
and every full gate remain required. See [[Implementation Witness Delivery]].

Resolved shape boundary (#735): type projection retains nominal/rigid applications,
references, tuples, functions, dynamic traits and capability wrappers recursively.
Only unresolved/error types become invalid syntax; no alias argument reordering
is reconstructed from authored syntax.

Responsibility review: the property expands this small module beyond 15 percent,
but remains one projection boundary. Keep runtime dispatch and loaded-graph
behavior in their existing suites; do not turn this module into a generic evaluator harness.

## Complete provider selections (#735)

ProviderSelection carries canonical trait identity, complete formed trait arguments
and an optional complete receiver type. Existing identity-only recording keeps an
empty argument list and no receiver. Unambiguous rigid-bound selections retain
the selected bound arguments and actual receiver, including F[A] rather than F.
Implementation trait facts retain formed arguments under implementation rigids.
Final checker publication resolves inference in both arguments and receiver.
Detailed products and ModuleTypes preserve this immutable typed evidence.

Compiler Literals continues existing member-symbol projection in this partition.
At the structural Impl trait boundary it projects the complete formed trait,
including expanded aliases and nested canonical owners; tooling syntax stays
authored. Runtime transport/consumption follows separately and #735 remains open.

Resolved Grill Log: trait identity cannot recover a parameter present only in
Choice[B] for Box[A]. Do not fabricate a nominal identity to hold receiver types,
inspect container elements, overwrite target-owner facts, or drop applied receiver
arguments while following a rigid constructor's bounds. Assert actual checker
products, canonical implementation trait projection, authored syntax and spans;
retain full existing dispatch, diagnostic, derive and cache gates.
See [[Bound Receiver Evidence Delivery]].
