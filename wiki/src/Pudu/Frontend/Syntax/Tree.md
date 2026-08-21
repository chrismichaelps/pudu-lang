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

Own the mutually recursive, recovery-capable, untyped syntax data described by the former [[Syntax]] signatures: `Module`, `Import`, visibility/binding kinds, declarations, parameters, type syntax, function bodies, blocks, statements, literals, and expressions.

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
  | FunctionDeclaration !Visibility !Bool !(Located Text) ![Located Parameter]
      !(Maybe (Located TypeSyntax)) !(Located FunctionBody)
  | InvalidDeclaration
data Parameter = Parameter
  { parameterName :: !(Located Text), parameterType :: !(Maybe (Located TypeSyntax))
  , parameterDefault :: !(Maybe (Located Expression)) }
data TypeSyntax
  = NamedType !ModuleName ![Located TypeSyntax] | ReferenceType !Bool !(Located TypeSyntax)
  | TupleType ![Located TypeSyntax] | UnitType | InvalidType
data FunctionBody = BlockBody !(Located Block) | ExpressionBody !(Located Expression)
data Block = Block
  { blockStatements :: ![Located Statement], blockResult :: !(Maybe (Located Expression)) }
data Statement
  = DeclarationStatement !(Located Declaration) | ExpressionStatement !(Located Expression)
  | ReturnStatement !(Maybe (Located Expression)) | InvalidStatement
data Literal
  = IntegerValue !Text | FloatValue !Text | StringValue !Text | CharValue !Char
  | BoolValue !Bool | NullValue
data Expression
  = LiteralExpression !Literal | NameExpression !(NonEmpty Text)
  | UnaryExpression !Text !(Located Expression)
  | BinaryExpression !(Located Expression) !Text !(Located Expression)
  | CallExpression !(Located Expression) ![Located Expression]
  | MemberExpression !(Located Expression) !(Located Text) | BlockExpression !(Located Block)
  | IfExpression !(Located Expression) !(Located Block) !(Maybe (Located Expression))
  | InvalidExpression
```

All constructors derive `Eq` and `Show` and are exported for parser construction and structural tests.

### Governance

- Data only: no parsing, desugaring, type logic, traversal framework, or evaluator behavior.
- Invalid nodes are explicit poison and never lower.
- Mutually recursive types remain co-located to avoid `hs-boot` cycles.

### Linkage

- **Requires:** [[Syntax Located]], [[Syntax Name]], [[Pudu Program]], [[Pudu Type]].
- **Consumed by:** [[Syntax]] and future parser-expression, parser-declaration, and name-resolution modules.

## Algorithm

No algorithm; strict algebraic representation with derived equality/show for tests.

## Negative Logic (Prohibited Paths)

- No smart semantic defaults, hidden source global, or phase annotations.

## Edge Cases

- Empty block/module lists and explicit invalid nodes are representable for recovery.

## Depth

DEPTH 0.56 (MEDIUM). Breadth is inherent to the grammar; co-location is deliberate data recursion, not monolithic logic.

## Grill Log

- **Q:** Split each recursive data type with `hs-boot`? **A:** No; keep the data knot in one behavior-free file. _Rationale:_ cycles add build complexity without modular behavior. _Rejected:_ artificial boot modules; all parser logic in the same file.

## Variants

- Later syntax families become separate files when they do not participate in this recursion knot.

## Referenced by

[[src/Pudu/Frontend/Syntax/_MOC]] · [[Syntax]] · [[Frontend]]
