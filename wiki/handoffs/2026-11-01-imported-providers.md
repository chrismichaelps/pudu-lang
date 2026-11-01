---
type: handoff
status: ACTIVE
aliases: [Imported Provider Delivery]
tags: [handoff, traits, typing]
---
# Imported Provider Delivery

Issue #734 resumes on fresh feature/734-imported-method-providers from fetched
dev e85b0100e with fully locally tested #777 prerequisite 0ac05ff8 integrated.
Dev 581b5b789 is integrated after #778 delivery. Preserve the older evidence and
collision branches as references; do not merge their superseded broad changes.
No delegated agents; independent review is waived for this engine loop.

Architect → Semantic Engineer ownership: Type.Check.Method, new Method.Binding,
Type.Env, Type.Check, Type.Check.Call/Qualified, package registration, the existing trait-provider gate and
all matching mirrors/navigation. Do not change runtime dispatch or type syntax.

## Resolved Grill Log

The current original reproducer still reports E3013 at Second's implementation
merely because another imported trait supplies encode for Int. The checker
already has canonical per-provider schemes and executable bound-provider facts;
reuse them. Distinct canonical traits coexist, while an actual unqualified call
without selecting evidence reports E3013. Registration order is never preference.

Extract formed method binding from the existing 499-line Method module. A closed
MethodOrigin distinguishes interface and source declarations. MethodBinding keeps
the formed canonical receiver/provider, name, declaration span and complete scheme.
The binding module owns shared-slot admission, provider-specific keys, ambiguity
registration and own-module tooling publication. Formation, specialization,
inherited defaults and obligation proof remain in Method. Keep canonical key
spelling unchanged and re-export implementationMethodKey through Method.

If an occupied imported/shared slot has the same or unknown provider, preserve
its existing refusal/recovery. A distinct known canonical provider registers its
own scheme and marks the shared receiver/member ambiguous rather than refusing
the declaration. Preserve exact-head coherence, visibility, effects, defaults,
implementation/method bounds and original source spans. No new inference variables.

An ambiguity's help must name real admitted provider spellings rather than two
identical basenames. Check collects its local trait names and exact importedNames
overlay, independently of graph-wide names. Env stores the inverse provider/name
map lazily and only for this consumer; choose shortest then lexical spelling.
Provider-spelling lookup is demanded only on the diagnostic path. Do not retain
these per-consumer names in InstalledNames or publish them as executable facts.
Fallback names retain recovery behavior when earlier errors withheld identity.

Required evidence: importing distinct same-named traits without calling succeeds;
aliased and selected qualified calls preserve different result types; generic
bounded and captured calls choose their declared provider; wrong annotations stay
E3001; ordinary calls refuse once with E3013 at the caller and usable qualified
help. Cover both orders, mixed local/imported providers, duplicate/coherence
controls, both evaluators and off/cold/warm products. Add derive-closure coverage
under where-bound field evidence before claiming the issue complete. Preserve
conditional implementation dispatch as separate #735 work, not silently repaired.
Run focused and every clean full optimized gate; split before 600 changed lines.

Verification Engineer → Forensic Guardian: the no-call import regression failed
before admission repair; qualified alias execution then exposed E7001, and the
Wire/Json derive collector exposed a wrong-provider Number result. All are now
covered and pass. The warning-clean optimized build, trait-focused properties
and complete provider gate pass, including explicit/generic/retained calls,
selected/repeated aliases, mixed providers, lexical shadows, E3001/E3013/E3015
controls and the exact derive output across both evaluators and off/cold/warm
products. No source edits follow the clean full-gate start.

PR #779 merged as 308130087 after full local and hosted checks passed.
The full gate exposed static-owner receiver annotation regressions.
Static regressions pass after separating static scheme admission from receiver
evidence. The stale diagnostic-only suite was stopped after capturing failures.
Exact next action: observe full gate 43729 without restarting it; then measure
the clean committed tree and publish #734 if every gate passes.

## Referenced by

[[handoffs/_MOC]] · [[Type Check Method]] · [[Method Binding]] · [[Type Env]] · [[Type Check]] · [[Trait Provider Gate]]

## Projection boundaries

Qualified imported trait calls retain canonical callee owners. Nominal receiver
methods retain their selected provider after derive substitution. The matching
Call, Method and Compiler Literals mirrors own the complete resolved contracts.

Resolved static boundary (#734): staticMethodScheme shares method admission and
ambiguity checks without recording receiver-provider facts. A complete static
owner selects its implementation arguments through structural head matching; it
is never lowered to a runtime receiver. Existing static/derive suite cases cover
Array, Option, nested and reordered heads in both evaluators.
