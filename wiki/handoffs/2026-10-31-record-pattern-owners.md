---
type: handoff
status: ACTIVE
aliases: [Record Pattern Owner Delivery]
tags: [handoff, patterns, nominal]
---
# Record Pattern Owner Delivery

Issue #761 uses feature/761-record-pattern-owners from fetched dev 7d1bd58c with
explicit prerequisite #768 at dd8ebd3e. Wait for its merge before publishing.
Architect resolves the contract; Semantic Engineer owns Type.Env, Type.Check.Pattern
and Type.Exhaust; Runtime Engineer owns Compiler.Literals and Eval.Match; tests own
canonical-owners.mjs. Tooling Engineer owns CI registration of the existing five local owner/provider
gates through .github/workflows/ci.yml. Forensic Guardian reconciles all corresponding mirrors and changelog.
Independent review is waived by the owner for this loop. No delegated agents.

## Resolved Grill Log

A named record pattern on dynamic Label currently matches an unrelated same-named record,
and falsely closes coverage after its first arm. A statically B.Item subject also accepts an
A.Item pattern. Both are independently reproduced and reported in #761 comments 6550660473
and 6550717437. Nominal identity already distinguishes their values.

Instantiate a declared named record owner, unify it against the dereferenced subject, and
record that owner at the pattern span. Dynamic subjects generate existing trait obligations.
Project only executable named record patterns into canonical single-segment owner symbols;
match complete owned symbols while retaining raw host-pattern compatibility and anonymous
field-only patterns. Do not alter named-payload representation in this partition.

Refutability belongs to the checked pattern and its subject, not a globally loaded basename.
Keep checker-local Set Span test facts: named sum payload patterns always test; ordinary named
record patterns test when narrowing a dynamic subject. Capture the set for exhaustiveness via
a read-only accessor; do not publish it into interface snapshots or executable products.
Use the same span predicate for nested irrefutability and existing correlated coverage.
This preserves static record destructuring while a dynamic record pattern cannot cover every
possible trait implementation. Taken keys for ordinary records use canonical owner plus an
empty variant tag, so aliases agree without colliding with named sum constructors.
No per-match runtime map lookup, linear checker fact scan or new public syntax.

Required tests: dynamic records of distinct owners and same basename, reversed imports and both
evaluators; cache off/cold/warm; if-let/let-else, nested dynamic record fields, guarded/partial
patterns and true alias repetitions; static owner mismatch E3001; dynamic match without fallback
E5001; valid static record destructuring; existing sum and derive/coverage checks and full gates.
Focused record/sum gates and warning-free optimized builds pass, including positioned E3001,
E5001 and E3032, borrowed generic destructuring, nested dynamic fields and true repeated aliases.
An earlier compiler also rejects an exhaustive A.Item record match with E5001 after an unrelated
module declares a named sum variant Item; the regression gate now includes this case.
The clean full optimized repository gate passed, including the unrelated-variant regression.
CI registration adds the five already-passing local owner/provider gates to hosted integration;
Ruby YAML parsing verifies the five-command CI step; every existing step is preserved.
Forensic Guardian self-audit reconciles source, mirrors, backlinks and changelog.
Exact next action: publish this tested repair after prerequisite #768 merges, then implement named-payload
owner representation before further engine work.

## Referenced by

[[handoffs/_MOC]] · [[Type Env]] · [[Type Check Pattern]] · [[Type Exhaust]] · [[Compiler Literals]] · [[Eval Match]]
