---
type: module
path: "@root/src/Pudu/Frontend/Expand.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.78
depth_status: DEEP
coupling: 3.0
interface_stability: 0.8
tags: [module, deep]
aliases: [Macro Expansion]
---

# Macro Expansion

## Purpose

Replace every macro call with the macro's body, substituting arguments and renaming the bindings the body introduces, before name resolution runs.

## Interface

### Signatures

```haskell
expandModule :: Module -> (Module, [Diagnostic])
```

## Governance

- Expansion runs before name resolution, matching [[architecture/SEMANTICS]]'s ordering. The phases that follow never see a macro call, so none of them needs a rule for one.
- A parameter's declared kind is checked against the argument at the call: an expression parameter accepts anything, an identifier parameter accepts a bare name, a block parameter accepts a block. The diagnostic names the argument and the parameter, which is the point of typed parameters — a token-tree matcher can only describe its own state.
- Arity is exact. A macro takes what it declared, and a mismatch reports both counts.
- Every binding the body introduces is renamed at each expansion with a name no source text can spell. This is the hygiene rule [[grammar/pudu]] states, enforced rather than trusted: a `let` inside a body can neither capture an argument nor leak to the caller.
- A name the body merely mentions is left alone, and resolves where the macro was expanded. Definition-site resolution for free names needs expansion and resolution to share a representation and is recorded as open in [[Macro Design]].
- Arguments are expanded before they are substituted, so a macro receives fully expanded syntax and nesting terminates from the inside out.
- Expansion is bounded. A macro that expands into itself exhausts the depth budget and reports at the call that started it, rather than looping.
- Expanded syntax carries the call's span. A diagnostic inside an expansion therefore points at what the reader wrote, not at a position in a body they may not have read.
- A call that cannot expand becomes an explicit invalid node, so later phases do not explain the same defect a second time.

### Linkage

- **Requires:** [[Syntax Tree]], [[Diagnostic Model]], [[Source]], [[Macro Design]].
- **Consumed by:** [[Compiler Pipeline]], between parsing and [[Name Resolution]].

## Algorithm

Collect the module's macros, then walk every declaration and expression. At a call, check arity and kinds, bind parameters to arguments, rename the body's introduced bindings, substitute, retag with the call's span, and expand the result again at one greater depth.

## Negative Logic (Prohibited Paths)

- No name resolution, no typing, no evaluation, no access to the filesystem or host, no repetition or pattern matching over token trees, no expansion of item or statement positions, and no silent acceptance of a call it could not expand.

## Edge Cases

- A macro whose body contains another macro call expands the inner call after substitution, so a parameter may carry a call the outer body then places.
- A recursive macro reports once, at the outermost call, because the depth check fires before any further substitution.
- A module with no macros walks unchanged and reports nothing.

## Depth

DEPTH 0.78 (DEEP). One entry point hides collection, kind checking, hygiene renaming, substitution, span retagging, and depth bounding.

## Grill Log

- **Q:** Where does expansion belong in the pipeline? **A:** Between parsing and resolution. _Rationale:_ [[architecture/SEMANTICS]] says so, and it means no later phase carries a case for a construct that should already be gone. _Rejected:_ expanding during resolution, which would make the resolver's two passes see different trees.
- **Q:** How is hygiene enforced? **A:** By renaming the body's introduced bindings at each expansion. _Rationale:_ mechanical renaming is checkable and needs no cooperation from the macro author, which is exactly what the C preprocessor lacks. _Rejected:_ syntax contexts threaded through untyped token trees; trusting authors to pick unlikely names.
- **Q:** What span does expanded syntax carry? **A:** The call's. _Rationale:_ a reader debugging a diagnostic can see the call; they may never have opened the macro. _Rejected:_ the definition's span, which points into code the reader did not write; synthetic spans, which point nowhere.
- **Q:** Should an unexpandable call be left in the tree? **A:** No; it becomes an invalid node. _Rationale:_ leaving it would make every later phase carry a case for it and risk a second diagnostic for one mistake. _Rejected:_ leaving the call; aborting the compile.

## Variants

- Item and statement macros, repetition, and definition-site resolution for free names each extend this module; [[Macro Design]] records what each one still needs decided.

## Referenced by

[[src/Pudu/Frontend/_MOC]] · [[Macro Design]] · [[Compiler Pipeline]] · [[Name Resolution]] · [[Syntax Tree]]
