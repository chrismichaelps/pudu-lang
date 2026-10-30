---
type: handoff
status: ACTIVE
aliases: [Qualified Record Method Delivery]
tags: [handoff, semantics, nominal]
---
# Qualified Record Method Delivery

Issue #763 starts from fetched dev e26a8903, then explicitly integrates prerequisite PR #764
at 137bbdfe on feature/763-qualified-record-methods. That prerequisite merged in #764 as dev 769dbc71; the branch fast-forwards to that identical
prerequisite tree before publication. Preserve the separate record partition.
Architect owns scheme/canonical-symbol contracts; Semantic Engineer owns Type.Check.Qualified,
Call, Rule and Compiler.Literals; Tooling owns the CLI gate, manifest and mirrors. No delegated
agents. The project owner waived independent review for this engine delivery loop.

A.Item.label(&value) is rejected with E3033 even though A exports Item, its annotation and
ordinary value.label work, and Item.label works in the defining module. Call considered only
a one-segment owner, so it checked the intermediate type as a module value export.

## Resolved Grill Log

Share uninstantiated canonical method schemes across immediate and retained selection.
Keep local-value and module-export priority. Only declared concrete multi-segment owners are
extended; traits keep receiver-driven qualification. On successful concrete lookup, preserve
the canonical owner as an executable name symbol, including selected-type imports whose short
runtime aliases may collide. This reuses #761 owner facts and method keys; no second registry,
new syntax, runtime type checking or filesystem lookup. Type argument selection stays ordinary.
Known concrete missing members retain positioned namespace refusal. Diagnostics must not duplicate.

Required verification: failing baseline; module/selected-type aliases, direct/retained and generic
methods, static constructors, defining captures, both evaluators, cold/warm cache reuse; wrong
receiver/result types, absent/private members, lexical shadows, ambiguity and full gates.
The CLI regression fails before repair with E3033 at the intermediate imported type. After
repair the complete gate passes both import forms/orders, both evaluators, retained/generic
methods, static constructors, exported value receivers, checked cache reuse and every negative
oracle. All derive properties and the canonical-owner/provider gates pass. The optimized build
passes with warnings treated as errors. An attempted generated-owner syntax fixture was removed
because that internal form is deliberately absent from authored grammar; no grammar was changed.
The clean optimized repository gate passed in full, including the complete suite, all engine,
CLI, packaging, editor and documentation checks. Forensic Guardian parity audit covers complete
mirrors, source registration, navigation, private-input exclusion and bounded review size.
Exact next action: publish the dev-targeted PR and merge only after every hosted check passes.

## Referenced by

[[handoffs/_MOC]] · [[Type Check Qualified]] · [[Type Check Call]] · [[Type Check Rule]] · [[Compiler Literals]]
