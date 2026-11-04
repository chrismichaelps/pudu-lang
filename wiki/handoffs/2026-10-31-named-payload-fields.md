---
type: handoff
status: ACTIVE
aliases: [Named Payload Field Delivery]
tags: [handoff, semantics, nominal]
---
# Named Payload Field Delivery

Issue #761; feature/761-named-field-owners starts from fetched dev eac68eb7 and
explicitly integrates #769 at c8b6005d. Publish only after that prerequisite merges.
Architect resolves this contract; Semantic Engineer owns Type.Env, Type.Formation,
Type.Check.Pattern/Record/Rule/Call/Expression and test/sum-owners.mjs. Forensic
Guardian reconciles their mirrors, MOCs and changelog. Independent review remains
waived by the owner for this loop; no delegated agents.

## Resolved Grill Log

The verified program in issue comment 6550934891 rejects A.Item.Chosen{first}
with E3005 after loading B.Item.Chosen{second}. Field-name metadata is globally
keyed by label while payload types already retain their declaring owner.
Key names by that same owner/variant pair. Resolve complete visible paths once,
then obtain both shape components from that identity; share the pattern lookup
with constructions instead of maintaining a second basename resolver.

Named constructor value refusal must also use its resolved nominal result owner.
Move qualified constructor refusal into qualifiedVariantType and exported binding
refusal into ordinary namespace lookup. This removes unconditional basename tests
before lexical receiver admission and avoids duplicate E3034 on calls. Generated
constructor handling retains its existing path. This restores existing nominal
and lexical contracts; no public syntax, wire format or runtime representation changes.

Tests cover distinct named field shapes/types and generic substitution; both
import orders/evaluators and cache off/cold/warm; wrong/missing fields and wrong
types with positioned diagnostics; one E3034 for named constructor calls/values;
unrelated positional constructors with the same label and existing lexical admission regressions;
existing sum/record/derive gates and the full optimized repository gate.

Responsibility review: the Call edit exceeds 15% because removal of its global
precheck dedents the existing callee walk. It adds no responsibility; constructor
admission remains in Pattern and namespace binding admission remains in Rule.
The enlarged sum gate retains one nominal owner regression responsibility.

The warning-free optimized build, focused sum gate and clean full repository gate
all pass, including engine, derive, diagnostic, package and LSP checks. Introduced
wiki links resolve and the private-input boundary is preserved. Forensic Guardian
self-audit reconciles the seven source modules and gate with their mirrors.
Exact next action: publish this tested checker partition after #769 merges, then preserve
named-payload owner identity in runtime values before further engine work.

## Referenced by

[[handoffs/_MOC]] · [[Type Env]] · [[Type Formation]] · [[Type Check Pattern]] · [[Type Check Record]] · [[Type Check Rule]] · [[Type Check Call]] · [[Type Check Expression]] · [[Sum Owner Gate]]
