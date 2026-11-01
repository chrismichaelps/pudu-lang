---
type: module
path: "@root/test/sum-owners.mjs"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, test, runtime, nominal]
aliases: [Sum Owner Gate]
---
# Sum Owner Gate

`node test/sum-owners.mjs <optimized-compiler>` checks same-named sums and variants across
modules in both evaluators and import orders. Direct/generic/retained calls and folded constants
retain defining owners and captures, including cold/warm product reuse. Custom Ok/Err-labelled
async results stay intact. Native/source JSON node equality and variant display remain stable.
Wrong receiver types retain a positioned diagnostic. Scratch programs use subprocess deadlines
and are removed after every outcome.

Resolved Grill Log: assert observable output and independent type refusal; do not assert a private
owner encoding. Keep #761 open for named payloads and remaining evidence audits.

## Referenced by

[[src/_MOC]] · [[Positional Sum Owner Delivery]] · [[Eval Value]]

The gate also checks unequal dynamic-erased values from distinct module declarations. Resolved Grill Log: erased static views do not erase runtime identity.

## Constructor pattern ownership (#761)

Extend the gate with dynamic constructor narrowing, repeated aliases, guards, partial payloads and refutable conditions in both evaluators; pin absence of false W5001 and continued true repeated-owner warnings.

Resolved Grill Log: preserve declaration identity through checking, executable projection and usefulness; no per-match span lookup. See [[Constructor Pattern Owner Delivery]].

## Named payload field ownership (#761)

Add same-labelled named variants with different field names/types, qualified direct construction, generic field substitution, both import orders/evaluators and cache reuse. Assert positioned E3005/E3008/E3001 and one E3034 for forbidden named constructor values/calls, while unrelated positional constructors remain callable. Existing lexical admission gates remain mandatory.

Resolved Grill Log: field names and payload types come from one resolved owner/variant key. No runtime representation or field evaluation order changes in this partition. See [[Named Payload Field Delivery]].

## Named sum publication (#761)

Check same-labelled named dispatch, canonical dynamic patterns, folded/cache values, declaration-order storage with authored effects, lent writes, iteration and named-empty success/positioned E3034 refusal in both evaluators.

Resolved Grill Log: carry checked owner and field order through syntax; preserve authored effects, diagnostics and cache identity. See [[Named Sum Publication]].

## Variant namespaces (#766)

Add same-module unit/tuple/named variant coexistence and qualified runtime owner checks in both evaluators and cache modes. Assert E2012 at ambiguous bare uses with related declaration spans, local shadow success, E2001 genuine duplicates and preserved arity/unknown refusals.

Resolved Grill Log: declaration identity is owner-scoped; ambiguity belongs at an unqualified use and respects the selected lexical binding. See [[Variant Namespace Delivery]].

## Qualified head identity (#766)

Cover known type names that share variant labels in qualified calls and patterns; keep bare-label E2012 refusal.

Resolved Grill Log: an already qualified path must not be refused as a bare variant. Only an alias yields to a known type; ordinary values and import privacy retain their lookup. See [[Variant Namespace Delivery]].

## Constructor binding identity (#774)

Extend source cases for bare constructors sharing type names, selected/module-aliased imports, retained/folded values and ordinary constants matching named-variant schemes. Keep named-constructor refusals and scope/duplicate regressions in both evaluators and cache modes.

Resolved Grill Log: identity belongs to the selected binding; schemes remain type-only and ordinary shadows clear constructor roles. See [[Constructor Binding Delivery]].
