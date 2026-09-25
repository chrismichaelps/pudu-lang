---
type: module
path: "@root/src/Pudu/Lsp/Shapes.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
tags: [module, medium, tooling, lsp]
aliases: [Lsp Shapes]
---

# LSP Shapes

## Purpose

The declared shape of every sum and record type a program can see, keyed by canonical identity, for
completion to turn a checked type into candidates: a subject's variants, a receiver's fields.

## Interface

```haskell
data VariantShape = UnitVariant | TupleVariant [Located TypeSyntax] | RecordVariant [(Text, Located TypeSyntax)]
data SumShape    = SumShape    { sumModule :: ModuleName, sumTypeParams :: [Text], sumVariants :: [(Text, VariantShape)] }
data RecordShape = RecordShape { recordModule :: ModuleName, recordTypeParams :: [Text]
                               , recordFields :: [(Text, Bool, Located TypeSyntax)] }  -- name, mut, type
sumShapes, recordShapes :: ModuleName -> [Located Declaration] -> [(Text, shape)]
programSums    :: ProgramResult -> Map Text SumShape
programRecords :: ProgramResult -> Map Text RecordShape
renderTypeSyntax :: Map Text Type -> Located TypeSyntax -> Text
```

### Governance

- **Shapes use canonical identity.** Keys are the declaring module and the type's name — the same
  key `nominalKey` gives a checked `NominalType` — so two modules' `Point` never exchange fields and
  an imported record is found under the module that declared it.
- The root module's tooling syntax supplies its own (including private) declarations; the program's
  interface graph supplies every other module's exported ones. Nothing reparses source text.
- Shapes keep declared type syntax and the type's parameters, so a use's arguments are substituted
  when rendered: a `Box[Int]`'s `value: T` renders `Int`, nested arguments included.
- A receiver's type is resolved by the checker, which expands aliases and whose references are
  unwrapped by the caller, so an alias or `&Box` reaches the record it names.
- Shapes are completion metadata only; typing remains authoritative for what a program means.

### Linkage

- **Requires:** [[Syntax Tree]], [[Compiler Program]], [[Type Interface]], [[Type Value]].
- **Consumed by:** [[Lsp Server]] (builds them per analysis), [[Lsp Pattern Completion]],
  [[Lsp Completion]].

## Negative Logic (Prohibited Paths)

- Do not look a type up by its basename.
- Do not read field lists from documentation text or declaration source slices.

## Grill Log

- **Q:** Why store sum shapes when the documentation index already lists types? **A:** Documentation
  entries do not preserve a sum's variants and payload arity. _Rationale:_ completion needs exact
  constructor facts without widening the public documentation model. _Rejected:_ parsing rendered
  type documentation or offering every constructor in the program.
- **Q:** Why build record shapes from declarations instead of retaining the checker's declared-type
  environment? **A:** That environment is rebuilt per module from every import and would be kept
  alive for each module of every ordinary run. _Rationale:_ the tree and the interface graph are
  already held, and a checked receiver type is already canonical. _Rejected:_ a per-module copy of
  every imported declaration kept for the life of a program.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Context]] · [[Lsp Pattern Completion]] · [[Lsp Completion]] · [[Lsp Server]]
