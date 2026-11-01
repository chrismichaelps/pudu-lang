---
type: handoff
status: ACTIVE
aliases: [Runtime Witness Selection Delivery]
tags: [handoff, runtime, traits]
---
# Runtime Witness Selection Delivery

Fresh feature/735-runtime-witness-selection starts at dev 8f1a55b77,
with fully locally tested #781 prerequisite 516b9710 integrated explicitly.
Independent review is waived for this engine loop; no delegated agents.

Architect → Runtime Engineer owns Eval.ImplementationHead/TypeWitness,
Value/Install/Call.Path, Operator.Access, constructor initialization in Eval and
BindingFlowSpec, package registration, bound-provider gate and matching mirrors.
Semantic Engineer additionally owns parameterStaticCallee in Type.Check.Call and
its Expression consumers for #782. Preserve other work and keep each source below
500 lines, including the 499-line Value owner. Split before 600 changed lines.

## Resolved Grill Log

Installed closures share minimal canonical target/binder metadata. Match witnesses
structurally; repeated binders agree and applied lexical constructors retain their
canonical head. Preserve full Self and distinguish PendingHead from SelectedHead
so later arguments bind method parameters without overwriting impl parameters.
No program element inspection, new mutable registry or Function identity change.
Head-only parameters absent from the target are not guessed; complete bound
receiver/trait evidence remains the following required #735 partition.

T.member must select its rigid bound scheme rather than fall through as ErrorType.
Keep canonical provider facts at the inner member span and chosen arguments at
the whole application span. Reuse instantiateWith, argument/bound diagnostics,
ambiguity and lexical value precedence. Retained TypeApplication evaluates its
target once and binds witnesses through the shared helper; Operator.Access and
Path share witnessed member lookup across both evaluators.

The tentative Self-guard hypothesis was disproven and removed before commit.
#782 is a type-checker qualification defect, despite its E2010 diagnostic.
Its failure proof is retained. The expanded provider gate now passes reordered,
nested, alias and repeated heads, inferred/explicit/retained method arguments,
lexical shadows and positioned E3001/E3003/E3005/E3012/E3013/E3028 controls in
both evaluators and off/cold/warm products, including warm inode reuse.

The original #782 reproducer passes six evaluator/cache executions; static
properties pass. PR #781 merged as 7819898f8 after every hosted check passed
and its identical tree is integrated. Exact next action: run the clean full
gate on this committed source, then publish Closes #782 / Refs #735 if green.
#735 remains open until bounded receiver calls preserve caller witnesses.

## Referenced by

[[handoffs/_MOC]] · [[Runtime Implementation Head]] · [[Eval Type Witness]] · [[Bound Provider Gate]]
