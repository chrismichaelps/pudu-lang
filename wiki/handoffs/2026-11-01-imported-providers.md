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
Exact next action: observe the existing clean full-gate process, then run the
stage simulation on a clean committed tree. Publish the bounded #734 PR with
all evidence if green; require hosted checks before merge, then revalidate #735
before engine continuation. Do not restart live validation.

## Referenced by

[[handoffs/_MOC]] · [[Type Check Method]] · [[Method Binding]] · [[Type Env]] · [[Type Check]] · [[Trait Provider Gate]]

## Qualified imported trait calls (#734)

Admitted trait callees retain their canonical trait qualifier as an owner fact at
the original callee span, only after successful self-taking trait selection.
Reuse existing member-head lowering so evaluation never reads an alias namespace
for the qualifier. The receiver and remaining arguments still check once.
Qualified authored trait paths resolve through the exact consumer-visible name
map and yield to complete dotted value bindings; preserve legacy single-name and
generated paths. Env retains that forward map beside its lazy preferred spelling
map. Never resolve authored aliases from graph-wide hidden names.
Resolved Grill Log: unused-import admission alone exposed E7001 at A; canonical
trait selection must survive into executable syntax without runtime alias guesses.
See [[Imported Provider Delivery]].

Resolved nominal-provider boundary (#734): after derive substitution, a field's
receiver is nominal and its bound-directed provider can no longer be recovered
from its type alone. The final checker already selects an unambiguous visible
method and retains its actual canonical provider in methodProvider. Record that
provider at the member span whenever a registered nominal scheme is selected.
Preserve the builtin isMethodKey guard and missing-member behavior. Reuse the
existing provider-marker lowering; do not re-evaluate a receiver, guess from the
scheme, change runtime registries or copy global provider order into generated
syntax. The Wire/Json derive reproducer currently returns Json.Number to an Int
sum in both evaluators; exact 42/JSON/1 output remains required before completion.
See [[Imported Provider Delivery]].
