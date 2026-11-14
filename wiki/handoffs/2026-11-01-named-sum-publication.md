---
type: handoff
status: ACTIVE
aliases: [Named Sum Publication]
tags: [handoff, runtime, nominal]
---
# Named Sum Publication

Issue #761; feature/761-named-value-publication starts from dev b326f56c,
explicitly integrates tested foundation d9dda3b6 and merged checker delivery
dd1c6a1a. Architect owns the checked selection contract; Semantic Engineer owns
Type.Value/Env/Check, Type boundary, Check.Pattern/Record and Compiler.Literals.
Runtime Engineer owns Eval.Record, Eval tree/Compile/Loop.Kernel and its manifest.
Verification Engineer owns sum-owners; Forensic Guardian owns their complete
mirrors, MOCs and changelog. Independent review is waived for this delivery loop.
No delegated agents. Preserve other worktrees and unrelated changes.

## Resolved Grill Log

Represent owner facts as ConcreteOwner NominalId or VariantOwner NominalId Text
[Text]. Named facts carry label and declared field order; concrete method, impl,
ordinary record and positional-pattern facts retain their separate projection.
Provider evidence remains NominalId and cannot be overwritten at shared anchors.
Record named constructor and pattern selections after canonical shape resolution.

Executable constructors use an unspellable ::sum::/owner/label/declared-fields
path; named patterns use ::sum::/owner/label. Recurse into fields while keeping
spans and authored tooling syntax. No new surface AST or persisted fact table.
Existing checked syntax cache preserves the projected descriptor.

Eval.Record chooses the constructor and field-order plan from syntax. Compiled
and closed-region consumers prepare it once; all consumers evaluate fields in
authored order before rearranging values. Already ordered fields use identity.
Other named initializers use stable declaration ranks, preserving every supplied
field defensively without manufacturing missing values. Ranking uses existing
containers, never an environment lookup or global variant basename registry.
Ordinary records keep their existing representation; #519 remains open for them.
The shared policy is a real boundary consumed by three execution engines.

Positional patterns must refuse every named payload, including empty payloads,
with E3034 at the original pattern. Successful named-empty patterns remain valid.
Report the reproduced check/run mismatch under #761 before implementation.

Required evidence: distinct same-labelled owners through direct/generic/retained
methods, dynamic matching, constants and caches; field reads/lent writes; named
iteration, declaration-order equality/display with authored effects; empty named
patterns, positioned refusals and existing lexical diagnostics. Validate tree,
compiled and closed-region behavior, focused gates and the clean full gate.
Keep the publication diff below 600 changed lines; no public wire-byte changes.

## Validation and delivery

The expanded sum-owner source gate passes in both evaluators and import orders,
including cold/warm cache reuse, borrowed matching, lent replacement, custom async
labels, declaration-order equality/display, authored effects, iteration, closed
function construction and positioned named-empty E3034 refusal. The clean full
optimized repository gate passes. Introduced wiki links resolve and tracked
private inputs remain absent. Prerequisite #771 is merged to dev as 9742e0ca.

Exact next action: publish this tested partition to dev, then repair same-module
variant namespace admission in #766 and finish the remaining evidence audit.

## Referenced by

[[handoffs/_MOC]] · [[Compiler Literals]] · [[Eval Record Construction]] · [[Sum Owner Gate]]
