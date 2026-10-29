---
type: handoff
status: ACTIVE
aliases: [Qualified Constructor Delivery]
tags: [handoff, semantic, ark]
---
# Qualified Constructor Delivery

Issue #717 is a prerequisite found during engine #716. Branch feature/717-qualified-import-variants
starts from freshly fetched dev. Preserve the pending engine files in their separate checkout.
Ownership: Type/Check/{Expression,Pattern,Call}.hs, qualified-variants.mjs, CI/local registration, mirrors and
MOCs/changelog. Runtime files remain read-only unless the reproducer proves a runtime failure.

Role transition: Architect resolves complete visible constructor-path admission in the module
mirror; Semantic Engineer implements it using existing canonical variant metadata. Independent
implementation, Language Architect and Forensic Guardian reviews remain pending; no delegated
agents or self-approval. Existing #536/#538 cover a related local type-qualification hole; this
repair covers nested imported owners and tests both cases without merging other PRs.

The regression failed on the installed compiler with E3033 at imported sum owners. The first
optimized repair passes aliased/unaliased imports, generic and first-class construction, matching,
local qualification, wrong result types, visibility, missing members, named-field refusal and
lexical shadowing. Runtime lookup already agrees; no evaluator edits are required. The initial full suite caught two sum static-method regressions (derived JSON and builders).
Canonical method bindings now defer to existing selection; both focused regressions pass. The final
clean optimized -Werror build, full suite and every local repository gate pass. Compiled source
fingerprints match all three edited checker modules. Vault links and whitespace checks pass.

The repair remains a draft pending the required independent reviews; nothing is merged.

Exact next action: resume engine #716 using this optimized compiler, beginning with the saved
capsule-box fixture in the separate engine checkout.

## Referenced by

[[handoffs/_MOC]] · [[Type Check Expression]] · [[Qualified Variant Gate]]
