---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Eval/ImplementationHead.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Runtime Implementation Head]
tags: [module, runtime, traits]
---
# Runtime Implementation Head

Own immutable ImplementationHead with ordered impl binder names, complete checked
target syntax and PendingHead/SelectedHead state. Installed methods share their
pending metadata; selected closures retain it without changing Function identity.
No Value dependency, evaluator work, type inference or runtime element inspection.

## Resolved Grill Log

Parameter order alone cannot match Pair[B,A] or nested Array[Array[A]]. Retain the
canonical alias-expanded head produced by checking. SelectedHead reserves later
explicit arguments for method-local parameters. Eval Type Witness owns matching;
this closed data boundary avoids a recursive Value/module dependency.

## Referenced by

[[Eval Value]] · [[Eval Install]] · [[Eval Type Witness]] · [[Pudu Cabal Manifest]] · [[Runtime Witness Selection Delivery]]
