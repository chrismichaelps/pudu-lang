---
type: module
path: "@root/src/Pudu/Frontend/Syntax/Tree.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.56
depth_status: MEDIUM
coupling: 2.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Syntax Tree]
---

# Syntax Tree

## Purpose

Own the mutually recursive, recovery-capable, untyped syntax data for the whole surface language: `Module`, `Import`, visibility and binding kinds, every declaration form, generic parameters and constraints, type syntax, function bodies, blocks, statements, literals, patterns, match arms, and expressions.

## Interface

### Signatures

```haskell
data Module = Module
  { moduleSpan :: !Span, moduleName :: !(Located ModuleName)
  , moduleImports :: ![Located Import], moduleDeclarations :: ![Located Declaration] }
data Import = Import
  { importModule :: !(Located ModuleName), importAlias :: !(Maybe (Located Text))
  , importItems :: ![Located Text] }
data Visibility = Private | Exported
data BindingKind = Immutable | Mutable | CompileTime
data Declaration
  = BindingDeclaration !Visibility !BindingKind !(Located Text)
      !(Maybe (Located TypeSyntax)) !(Located Expression)
  | FunctionDeclaration !Function
  | TypeDeclaration !TypeDeclarationValue
  | TraitDeclaration !Trait
  | ImplDeclaration !Impl
  | InvalidDeclaration
data Function = Function
  { functionVisibility :: !Visibility, functionAsync :: !Bool
  , functionName :: !(Located Text), functionTypeParams :: ![Located TypeParam]
  , functionParameters :: ![Located Parameter], functionReturn :: !(Maybe (Located TypeSyntax))
  , functionConstraints :: ![Located Constraint]
  , functionBody :: !(Maybe (Located FunctionBody)) }
data TypeParam = TypeParam
  { typeParamName :: !(Located Text), typeParamBounds :: ![Located TypeSyntax] }
data Constraint = Constraint
  { constraintSubject :: !(Located Text), constraintBounds :: ![Located TypeSyntax] }
data TypeDeclarationValue = TypeDeclarationValue
  { typeVisibility :: !Visibility, typeName :: !(Located Text)
  , typeTypeParams :: ![Located TypeParam], typeDefinition :: !(Located TypeDefinition) }
data TypeDefinition
  = RecordDefinition ![Located FieldDeclaration] | SumDefinition ![Located Variant]
  | AliasDefinition !(Located TypeSyntax) | InvalidDefinition
data FieldDeclaration = FieldDeclaration
  { fieldMutable :: !Bool, fieldName :: !(Located Text), fieldType :: !(Located TypeSyntax) }
data Variant = Variant
  { variantName :: !(Located Text), variantPayload :: !VariantPayload }
data VariantPayload
  = UnitPayload | TuplePayload ![Located TypeSyntax] | RecordPayload ![Located FieldDeclaration]
data Trait = Trait
  { traitVisibility :: !Visibility, traitName :: !(Located Text)
  , traitTypeParams :: ![Located TypeParam], traitConstraints :: ![Located Constraint]
  , traitMembers :: ![Located Function] }
data Impl = Impl
  { implTypeParams :: ![Located TypeParam], implTrait :: !(Located TypeSyntax)
  , implTarget :: !(Located TypeSyntax), implConstraints :: ![Located Constraint]
  , implFunctions :: ![Located Function] }
data Parameter = Parameter
  { parameterName :: !(Located Text), parameterType :: !(Maybe (Located TypeSyntax))
  , parameterDefault :: !(Maybe (Located Expression)) }
data TypeSyntax
  = NamedType !ModuleName ![Located TypeSyntax] | ReferenceType !Bool !(Located TypeSyntax)
  | TupleType ![Located TypeSyntax] | FunctionType !Bool ![Located TypeSyntax] !(Located TypeSyntax)
  | UnitType | InvalidType
data FunctionBody = BlockBody !(Located Block) | ExpressionBody !(Located Expression)
data Block = Block
  { blockStatements :: ![Located Statement], blockResult :: !(Maybe (Located Expression)) }
data Statement
  = DeclarationStatement !(Located Declaration) | ExpressionStatement !(Located Expression)
  | ReturnStatement !(Maybe (Located Expression))
  | BreakStatement | ContinueStatement | InvalidStatement
data Pattern
  = WildcardPattern | BindingPattern !(Located Text) | LiteralPattern !Literal
  | RangePattern !Literal !Bool !Literal | TuplePattern ![Located Pattern]
  | ConstructorPattern !ModuleName ![Located Pattern]
  | RecordPattern !(Maybe ModuleName) ![Located FieldPattern] !Bool
  | AlternativePattern ![Located Pattern] | InvalidPattern
data FieldPattern = FieldPattern
  { fieldPatternName :: !(Located Text), fieldPatternValue :: !(Maybe (Located Pattern)) }
data FieldInit = FieldInit
  { fieldInitName :: !(Located Text), fieldInitValue :: !(Maybe (Located Expression)) }
data MatchArm = MatchArm
  { armPattern :: !(Located Pattern), armGuard :: !(Maybe (Located Expression))
  , armBody :: !(Located Expression) }
data Literal
  = IntegerValue !Text | FloatValue !Text | StringValue !Text | CharValue !Char
  | BoolValue !Bool | NullValue
data Expression
  = LiteralExpression !Literal | NameExpression !(NonEmpty Text)
  | UnaryExpression !Text !(Located Expression)
  | BinaryExpression !(Located Expression) !Text !(Located Expression)
  | CallExpression !(Located Expression) ![Located Expression]
  | MemberExpression !(Located Expression) !(Located Text)
  | IndexExpression !(Located Expression) !(Located Expression)
  | TryExpression !(Located Expression) | AwaitExpression !(Located Expression)
  | TupleExpression ![Located Expression]
  | ArrayExpression ![Located Expression]
  | RecordExpression !ModuleName ![Located FieldInit]
  | BlockExpression !(Located Block)
  | IfExpression !(Located Expression) !(Located Block) !(Maybe (Located Expression))
  | MatchExpression !(Located Expression) ![Located MatchArm]
  | WhileExpression !(Located Expression) !(Located Block) | LoopExpression !(Located Block)
  | ForExpression !(Located Pattern) !(Located Expression) !(Located Block)
  | InvalidExpression
```

All constructors derive `Eq` and `Show` and are exported for parser construction and structural tests.

### Governance

- Data only: no parsing, desugaring, type logic, traversal framework, or evaluator behavior.
- Invalid nodes are explicit poison and never lower.
- Mutually recursive types remain co-located to avoid `hs-boot` cycles.
- A declaration form with more than three components is a named record rather than a positional constructor, so adding a field to `Function`, `Trait`, or a type declaration cannot silently reorder existing arguments at a call site.
- An absent `functionBody` means a trait member declared without a default; it is the one legitimate bodiless function and is never produced at module scope.
- Patterns are syntax only: alternation is flat, a range keeps two literal endpoints, and a record rest is an explicit flag rather than an implied field list.

### Linkage

- **Requires:** [[Syntax Located]], [[Syntax Name]], [[Pudu Program]], [[Pudu Type]].
- **Consumed by:** [[Syntax]], every parser module under [[src/Pudu/Frontend/Parser/_MOC]], and future name-resolution and typing phases.

## Algorithm

No algorithm; strict algebraic representation with derived equality/show for tests.

## Negative Logic (Prohibited Paths)

- No smart semantic defaults, hidden source global, or phase annotations.

## Edge Cases

- Empty block/module lists and explicit invalid nodes are representable for recovery; `InvalidDefinition` and `InvalidPattern` extend that poison discipline to type definitions and patterns.

## Depth

DEPTH 0.56 (MEDIUM). Breadth is inherent to the grammar; co-location is deliberate data recursion, not monolithic logic.

## Grill Log

- **Q:** Split each recursive data type with `hs-boot`? **A:** No; keep the data knot in one behavior-free file. _Rationale:_ cycles add build complexity without modular behavior. _Rejected:_ artificial boot modules; all parser logic in the same file.

## Variants

- Later syntax families become separate files when they do not participate in this recursion knot.

## Referenced by

[[src/Pudu/Frontend/Syntax/_MOC]] · [[Syntax]] · [[Parser Expression]] · [[Parser Import]] · [[Parser Binding]] · [[Frontend]]
