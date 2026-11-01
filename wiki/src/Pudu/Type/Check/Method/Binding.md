---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Type/Check/Method/Binding.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Method Binding]
tags: [module, traits, typing]
---
# Method Binding

## Purpose and interface

Own MethodOrigin (InterfaceMethod or SourceMethod), the formed MethodBinding
record, bindMethod, methodKey and implementationMethodKey. Input retains the
canonical receiver, optional canonical trait, located member name, declaration
span and complete formed Scheme. Do not form syntax or infer types here.

## Algorithm and invariants

Inspect the shared receiver/member slot and actual earlier provider. Preserve
existing imported/source same-provider or unknown-provider collision refusal.
A distinct known canonical provider is admitted, stores its own scheme under the
unchanged trait/receiver/member key and marks the shared slot ambiguous. Keep all
providers through Env's existing deduplicated accumulator. Source methods record
original tooling name spans; interface methods retain imported markers. Every
scheme keeps implementation and method parameters/bounds from formation.

## Negative logic and edge cases

Never select the first/last provider, erase canonical identity to a basename,
instantiate a scheme, allocate fresh variables, bypass coherence, load source or
install runtime values. Same-receiver methods from different traits are not
same-trait duplicate heads. Unknown providers retain the old error recovery.

## Resolved Grill Log

Registration is a cohesive phase boundary between formed schemes and candidate
selection. Extract its policy from Method before adding cross-module admission,
keeping the existing owner below 500 lines. The shared slot answers ambiguity;
provider-specific slots answer explicit selection. Preserve key format and the
existing Method re-export for consumers. See [[Imported Provider Delivery]].

## Referenced by

[[Type Check Method]] · [[Type Env]] · [[Pudu Cabal Manifest]] · [[src/Pudu/Type/_MOC]] · [[Imported Provider Delivery]]

Resolved #734 qualifier contract: retain exact admitted name lookup separately from preferred diagnostic spellings; successful explicit self-taking trait calls publish their canonical qualifier through the existing member owner-fact projection. Preserve argument order and static-member behavior. See [[Imported Provider Delivery]].
