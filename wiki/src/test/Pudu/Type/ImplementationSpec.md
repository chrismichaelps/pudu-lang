---
type: module
path: "@root/test/Pudu/Type/ImplementationSpec.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, trait, derive]
aliases: [Type Implementation Proof Spec]
---

# Type Implementation Proof Spec

## Purpose and interface

`implementationProperties` exercises complete compiler admission for conditional,
specialized and repeated-parameter heads, dynamic widening and imported rules.
Structured proof tests cover complete generic trait applications, markers, cycles,
alternatives and resource exhaustion for the derive field-proof boundary.

## Algorithm and evidence

Compile ordinary caller programs whose generic bound sees a concrete Box or Pair.
Positive inputs satisfy all conditions; incompatible arguments and missing nested
requirements report one E3012 at the caller. Dynamic incompatibility reports E3032.
Loaded graph fixtures put traits and implementations in different modules and
verify canonical imported conditions remain intact. Compare typed proof outcomes
for full trait applications, a circular premise, another valid candidate and
depth/work exhaustion; no body evaluation is used as capability evidence.

## Negative logic and edge cases

Do not assert only owner lookup or mirror constructors as sole evidence. Ordinary
compiled source is the primary regression. Pure proof fixtures isolate budget and
full-application boundaries without manufacturing source offsets.
Cover an implementation parameter appearing only in a recursive trait condition:
infer it from the nested implementation, preserve existing iterator widths, and
refuse a mismatching conditional argument. Failed candidates cannot mutate caller
inference or capture same-spelled rigid bounds.

## Grill Log

- **Q:** Check only a generated derive's method calls? **A:** No; ordinary bounded
  calls and dynamic widening use the same capability proof. _Rationale:_ a derive
  field solver cannot be sound while general calls erase the same conditions.
  _Rejected:_ tests that merely inspect a retained conditional list.

## Referenced by

[[Type Trait Proof]] · [[Type Implementation Rules]] · [[Repository Test Runner]] ·
[[Pudu Test Cabal Manifest]] · [[src/_MOC]]

Full scoped-application matrices cover concrete and rigid argument mismatches, immediate and captured result types, trait defaults and derive-contract strength. Private evidence tests force later-premise backtracking, delayed subject inference and caller substitution preservation. Resolved Grill Log: prove a successful alternative only after all its remaining premises succeed.

Unique call-bound inference covers parameters occurring only in trait arguments,
explicit argument disambiguation, conflicting shared obligations and multiple
successful applications. Proof proposals do not alter the checker until committed;
unknown target owners are never guessed; arguments require unique evidence. Resolved Grill Log: successful
existential evidence alone is insufficient when applications disagree.

Documentation evidence compiles alpha-renamed generic functions, compares their
structural signatures and verifies complete bound arguments in rendering and JSON.
Resolved Grill Log: source compilation and public serialization both consume the
shared Scheme contract; neither may silently drop its generic requirements.

Constructor-bound evidence checks the established F[_]: Mappable shorthand against
an explicit application, a different canonical constructor and a mismatching
trait-parameter kind. Resolved Grill Log: preserve the shorthand through typed
formation rather than accepting every application of its trait owner.

Generic-header source cases include self and forward type-parameter references,
an absent bound argument and repeated parameter declarations. Resolved Grill Log:
collecting a generic header must retain missing-name and duplicate diagnostics.
