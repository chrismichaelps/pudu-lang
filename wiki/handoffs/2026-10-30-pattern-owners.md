---
type: handoff
status: ACTIVE
aliases: [Constructor Pattern Owner Delivery]
tags: [handoff, runtime, nominal, patterns]
---
# Constructor Pattern Owner Delivery

Issue #761 uses feature/761-pattern-owners, created from fetched dev 5f6c8bb58 and
explicitly integrating prerequisite #767 at 71981946, then fast-forwarding to its merged
dev head 7d1bd58c. All five hosted checks passed before that prerequisite merge.
The owner waived independent review for this loop; no delegated agents.
Architect resolves the pattern contract; Semantic Engineer owns Type.Check.Pattern,
Type.Exhaust and its Expression/Statement callers; Runtime Engineer owns Compiler.Literals,
Eval.Match and the sum-owner gate. Forensic Guardian owns matching mirrors and parity.

## Resolved Grill Log

Dynamic trait values can contain unrelated nominal sums with the same variant label.
The existing reproducer matches B.Item.Chosen with the A.Item.Chosen arm and falsely
warns W5001 for the actual B arm. Checking already resolves canonical constructor owners.
Record that owner at each positional pattern span using the existing owner fact channel.
Project only executable ConstructorPattern paths into a single internal canonical owner/tag
symbol that authored identifiers cannot spell. Match that complete symbol against carried
SumValue owner/tag, preserving raw host-pattern compatibility and payload recursion.
Tooling syntax, spans and existing stored-product traversal stay unchanged.

Usefulness keys include canonical owner and tag, resolved by the same variantForPath helper
rather than authored aliases or global tag identity. Unknown owners contribute no taken key.
Pass declared scope explicitly through both exhaustiveness callers. Guards, alternative
all-branches admission, numeric literal keys and correlated closed-domain matrices stay intact.
No runtime span lookup or global owner-list scan. Named payload representation and ordinary
record narrowing remain separate audits; do not declare all #761 matching fixed.

Required tests: both owners and evaluator modes/import orders; dynamic narrowing and wildcard,
if-let and let-else; nested constructor payloads; repeated aliases of the same owner still warn;
distinct owners do not warn; guard and partial payload behavior; cache off/cold/warm;
existing diagnostic, derive, correlated coverage and full optimized repository gates.
The optimized build and expanded sum-owner gate pass. Both evaluators, reversed imports,
cache off/cold/warm, nested Option payloads, if-let/let-else and repeated-owner aliases are covered.
An earlier compiler independently prints first and false W5001 for the Second.Item reproducer.
The clean full optimized repository gate passed, including all Ark, codec, derive, diagnostic,
residency, package, lint, language-server, watch and documentation checks.
Forensic Guardian self-audit confirms source/mirror parity and bounded scope. Remaining named-payload dispatch and ordinary dynamic
record narrowing are independently reproduced in issue #761 comment 6550660473.
Exact next action: publish this tested pattern repair, then repair dynamic
record-pattern ownership/refutability before named-payload representation and engine work.

## Referenced by

[[handoffs/_MOC]] · [[Type Check Pattern]] · [[Type Exhaust]] · [[Compiler Literals]] · [[Eval Match]]
