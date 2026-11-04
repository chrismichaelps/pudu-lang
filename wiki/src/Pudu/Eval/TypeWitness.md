---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Eval/TypeWitness.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Eval Type Witness]
tags: [module, runtime, traits]
---
# Eval Type Witness

Own lexical witness construction, ordered explicit selection and structural matching of implementation targets, without inference or runtime element inspection.

## Structural implementation witnesses (#735)

Installed methods retain one shared minimal ImplementationHead: ordered impl
binder names, the complete checked target syntax and PendingHead/SelectedHead
state. Ordinary functions/literals have no head. Closure identity/captures and
MultiMap proof semantics stay unchanged; constructor fixtures initialize None.
Keep Value below 500 lines by removing one redundant blank line, not semantics.

Eval Type Witness owns witnessOf, selectTypes and withSelf (re-exported by Path)
and structural implementation matching. Nominal identity and all argument
structure match exactly; repeated binder assignments must agree. Applied lexical
constructor witnesses retain their selected canonical head. Structural witnesses
use unspellable tags for tuples, references, functions, dynamic and capability
wrappers, never user record values or element inspection. A witnessed method
matches the checked target before binding impl names and complete Self; selected
heads make later explicit arguments bind method-local parameters only. Preserve
legacy no-head selection. Mismatch reports located E7001, never guesses bindings.

Resolved Grill Log: Pair[B,A] and Array[Array[A]] currently bind by zipping owner
arguments, producing wrong values in both evaluators. Match the checked target;
do not change source syntax, infer from runtime elements or erase method-local
arguments. Keep original Function/capture identity. This partition repairs
witnessed static selection and prepares bounded receiver evidence; #735 remains
open until the latter is integrated and all original cases pass.

## Referenced by

[[Eval Value]] · [[Eval Install]] · [[Eval Call Path]] · [[Pudu Cabal Manifest]] · [[Runtime Witness Selection Delivery]]

Resolved partial-head boundary: parameters absent from the target retain their
existing unbound state until complete trait-application evidence is connected;
never invent them from receiver contents. This partition does not close #735.

## Retained witnessed members (#735, #782)

readMember recognizes TypeWitnessValue before ordinary data access and delegates
to Eval Type Witness.witnessMethod. That helper owns canonical provider lookup
and structural target matching and is shared by Path qualification. A miss is
located E7001. Both evaluators use this access boundary; no duplicate selection
logic or receiver re-evaluation. Resolved Grill Log: retained T.method must carry
the same checked head and method-local witnesses as an immediate qualified call.
