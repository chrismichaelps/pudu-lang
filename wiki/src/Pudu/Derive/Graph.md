---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Derive/Graph.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, expansion]
aliases: [Derive Graph]
---

# Derive Graph

## Purpose and interface

`elaborateGraph` accepts one loaded map of parsed modules and returns elaborated
ordinary modules plus per-module diagnostics. No-derive graphs pass through
unchanged. The compiler consumes this boundary before final interface publication
and before any ordinary body checking or folding. This is the graph orchestration
boundary; the currently available Record kernel is extended separately for Sum
and builders before full Derive delivery can be claimed.

The shared aggregate entry currently also admits shape-independent Sum methods;
variant reflection and builders remain separate required integration work.

The Sum descriptor extension retains the same generic definition validation,
conditional-field proof and canonical generated placement gates; it delegates
ordinary pattern synthesis to [[Derive Sum Residualizer]]. Builders remain pending.

Field obligations are formed in the defining module's scope extended with the graph's qualified names, the defining module's own names winning: field types are canonical and may name modules the definition never imported. E3092 is reported at the authored field as `Owner.field: Type does not implement Trait, which derive Trait requires of every field`, with the request noted once.

## Algorithm and invariants

Expand macros across the graph first. Collect the canonical catalogue and validate
headers/definitions once in their defining environments. Gate all later generation
on admission; ordinary unresolved header names precede catalogue selection.
Definition duplicate contract findings precede the equivalent local catalogue
duplicate finding, so one mistake reports once. Select an abstract validated
candidate matching the full trait
application and target shape. Check canonical original request ownership.

Use one request-owned Residual state to apply actual target arguments, normalize
target parameter bounds, reconstruct canonical trait/target syntax, instantiate
methods and tag the ordinary Impl declaration. Reflection facts come exclusively
from the admitted defining resolution. No constructor can promote an unchecked
template. Remove template declarations/requests and inline derives from the
executable graph; append generated methods to their definition module, leaving
all ordinary bodies and lexical imports intact.

Before publication, check overlap against all ordinary and generated canonical
heads. Infer field obligations through the shared trait solver with only bare
authorized target parameters eligible as premises. Generated heads are provisional
within this closed graph phase. Rebuild the graph with monotonically accumulated
conditional parameter bounds until all requirements stabilize. This propagates
requirements through nested and mutually generated heads; an unconditional
provisional wrapper cannot erase its eventual leaf capability. Ordinary declared
target bounds remain scoped evidence. Any concrete absence or exhausted proof
refuses the entire elaboration product. Bound rounds and total obligation visits
by shared compile-time limits; generated syntax has the request's existing node,
depth and iteration limits.

## Diagnostics and negative logic

E3091 reports missing/inaccessible/wrong-shape strategies at requests. E3092 reports
an unmet field capability at its authored field with the request attached. E3093
reports bounded expansion/coherence/proof exhaustion or unsupported residual work.
Definition author errors occur once before requests. A failed phase publishes no
generated evidence and the compiler skips later body checking to avoid cascades.
No IO, source-string generation, added imports, runtime metadata, compiler-known
trait names or implicit field derives. No performance or complete-library claim
is inferred from kernel or graph tests.

## Grill Log

- **Q:** Publish unconditional generic heads permanently? **A:** Keep them
  provisional inside a closed fixed-point phase and admit stabilized field
  evidence only. _Rejected:_ dropping nested generic constraints or trusting
  an unvalidated request as ordinary trait evidence.
- **Q:** Transplant private helper bodies or add imports? **A:** Preserve the
  template's existing definition module and append only generated impls.
  _Rejected:_ concatenating modules or capturing consumer bindings.
- **Q:** Restart identity counters while preparing a target? **A:** One Residual
  state covers preparation and the complete generated impl. _Rejected:_ spans
  colliding between head, fields, methods and inferred bounds.
- **Q:** Form a canonical field type in the defining scope alone? **A:** No; `Main.Tree` is unknown there, which refused recursive and cross-module fields.
- **Q:** Report at the generated field span? **A:** No; at its authored span, so the field's own provenance notes do not repeat the request.

## Linkage and references

Requires [[Derive Catalogue]], [[Validated Derive Definitions]],
[[Derive Target Application]], [[Derive Record Residualizer]], [[Derive Graph Coherence]],
[[Trait Proof]], [[Type Interface Graph]] and [[Macro Expander]]. Referenced by
[[Compiler Program]] · [[Derive Design]] · [[src/_MOC]].
