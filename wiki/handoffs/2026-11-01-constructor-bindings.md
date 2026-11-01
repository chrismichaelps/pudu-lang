---
type: handoff
status: ACTIVE
aliases: [Constructor Binding Delivery]
tags: [handoff, typing, nominal]
---
# Constructor Binding Delivery

Issue #774; feature/774-constructor-bindings begins from fetched dev 65b1efed
and integrates tested prerequisite 503244c7 (#773). Architect → Semantic Engineer:
resolve binding identity before implementation. Ownership is Type.Env,
Type.Check, Check.Install/Import/Prelude/Rule and the loaded sum-owner gate.
Verification Engineer runs focused and full gates; Forensic Guardian reconciles
these mirrors, MOCs and changelog before delivery. Independent review is waived
for this loop. No delegated agents; preserve other worktrees and unrelated work.

## Resolved Grill Log

Bare Token denotes a real unit constructor, but its runtime namespace overwrites
the same spelling. An ordinary imported constant named HELD also receives false
E3034 because its scheme resembles a named constructor. Schemes describe types;
they do not identify bindings. Do not derive constructor identity from either a
name or result scheme.

NameBinding is ValueBinding Scheme or ConstructorBinding NominalId Text Scheme.
Checker name frames and InstalledNames carry these closed values. Ordinary
bindName clears constructor identity; bindConstructorName records the actual
formed declaration owner and original variant label. aliasName copies the whole
selected binding, while existing restriction inheritance remains at callers.
Lookup reads the nearest frame once; ordinary lookup APIs expose only its scheme.
Final tooling publication still yields schemes after substitution.

Local and interface constructors, including wired-in Option/Result, are marked
at declaration. Interface publication and consumer imports copy binding roles.
Rule namespace value lookup inspects the actual selected binding: ordinary values
instantiate normally; a constructor checks named-value refusal under its original
label and records VariantOwner only for an admitted value. Existing executable
lowering produces the owned constructor directly. No runtime installer, public
wire format, type equality or authored tooling syntax changes are needed.

The Env state-owner exception remains bounded to name/frame representation and
accessors. Installed snapshots remain immutable and carry the same fresh-variable
counter. Alias copying introduces no new inference variables or consumer-state
sharing. Preserve local shadowing, imports, capabilities and compile-time policy.

Required evidence: bare unit/positional constructors sharing type names; local,
selected and module-aliased imports; retained and folded constructors, ordinary
constants with matching named-variant schemes; named constructor E3034; ambiguous
bare and duplicate refusals; both evaluators and off/cold/warm caches. Run the
focused source gate and clean full optimized gate. Split before 600 changed lines
and keep the issue open if required evidence or implementation remains.

Exact next action: implement binding roles and alias preservation, validate the
reported check/run and false-refusal cases, then run focused and full gates.

## Referenced by

[[handoffs/_MOC]] · [[Type Env]] · [[Type Check Rule]] · [[Type Check Install]] · [[Type Check Import]] · [[Type Check Prelude]] · [[Sum Owner Gate]]
