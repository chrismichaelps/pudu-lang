{-| @Program.Syntax.Tree — models recoverable surface structure -}
module Pudu.Frontend.Syntax.Tree
  ( BindingKind (..)
  , Block (..)
  , Constraint (..)
  , Declaration (..)
  , Expression (..)
  , FieldDeclaration (..)
  , FieldPattern (..)
  , Function (..)
  , FunctionBody (..)
  , Impl (..)
  , Import (..)
  , Literal (..)
  , MatchArm (..)
  , Module (..)
  , Parameter (..)
  , Pattern (..)
  , Statement (..)
  , Trait (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , TypeParam (..)
  , TypeSyntax (..)
  , Variant (..)
  , VariantPayload (..)
  , Visibility (..)
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located)
import Pudu.Frontend.Syntax.Name (ModuleName)
import Pudu.Source (Span)

{-| @Program.Syntax.Module — groups imports and declarations -}
data Module = Module
  { moduleSpan :: !Span
  , moduleName :: !(Located ModuleName)
  , moduleImports :: ![Located Import]
  , moduleDeclarations :: ![Located Declaration]
  }
  deriving stock (Eq, Show)

{-| @Module.Syntax.Import — records one explicit dependency -}
data Import = Import
  { importModule :: !(Located ModuleName)
  , importAlias :: !(Maybe (Located Text))
  , importItems :: ![Located Text]
  }
  deriving stock (Eq, Show)

{-| @Module.Syntax.Visibility — marks explicit public declarations -}
data Visibility = Private | Exported
  deriving stock (Eq, Ord, Show)

{-| @Program.Syntax.BindingKind — distinguishes binding lifetime policy -}
data BindingKind = Immutable | Mutable | CompileTime
  deriving stock (Eq, Ord, Show)

{-| @Program.Syntax.Declaration — models admitted declaration forms -}
data Declaration
  = BindingDeclaration
      !Visibility
      !BindingKind
      !(Located Text)
      !(Maybe (Located TypeSyntax))
      !(Located Expression)
  | FunctionDeclaration !Function
  | TypeDeclaration !TypeDeclarationValue
  | TraitDeclaration !Trait
  | ImplDeclaration !Impl
  | InvalidDeclaration
  deriving stock (Eq, Show)

{-| @Program.Syntax.Function — carries one complete function signature. The body
    is absent only for a trait member that declares behavior without providing
    a default implementation. -}
data Function = Function
  { functionVisibility :: !Visibility
  , functionAsync :: !Bool
  , functionName :: !(Located Text)
  , functionTypeParams :: ![Located TypeParam]
  , functionParameters :: ![Located Parameter]
  , functionReturn :: !(Maybe (Located TypeSyntax))
  , functionConstraints :: ![Located Constraint]
  , functionBody :: !(Maybe (Located FunctionBody))
  }
  deriving stock (Eq, Show)

{-| @Type.Syntax.TypeParam — one declared generic parameter and its bounds -}
data TypeParam = TypeParam
  { typeParamName :: !(Located Text)
  , typeParamBounds :: ![Located TypeSyntax]
  }
  deriving stock (Eq, Show)

{-| @Type.Syntax.Constraint — one `where` obligation -}
data Constraint = Constraint
  { constraintSubject :: !(Located Text)
  , constraintBounds :: ![Located TypeSyntax]
  }
  deriving stock (Eq, Show)

{-| @Type.Syntax.Declaration — names a record, sum, or alias definition -}
data TypeDeclarationValue = TypeDeclarationValue
  { typeVisibility :: !Visibility
  , typeName :: !(Located Text)
  , typeTypeParams :: ![Located TypeParam]
  , typeDefinition :: !(Located TypeDefinition)
  }
  deriving stock (Eq, Show)

{-| @Type.Syntax.Definition — distinguishes the three declared shapes -}
data TypeDefinition
  = RecordDefinition ![Located FieldDeclaration]
  | SumDefinition ![Located Variant]
  | AliasDefinition !(Located TypeSyntax)
  | InvalidDefinition
  deriving stock (Eq, Show)

{-| @Type.Syntax.Field — one record field and its declared mutability -}
data FieldDeclaration = FieldDeclaration
  { fieldMutable :: !Bool
  , fieldName :: !(Located Text)
  , fieldType :: !(Located TypeSyntax)
  }
  deriving stock (Eq, Show)

{-| @Type.Syntax.Variant — one sum variant and its payload shape -}
data Variant = Variant
  { variantName :: !(Located Text)
  , variantPayload :: !VariantPayload
  }
  deriving stock (Eq, Show)

{-| @Type.Syntax.VariantPayload — unit, positional, or record payload -}
data VariantPayload
  = UnitPayload
  | TuplePayload ![Located TypeSyntax]
  | RecordPayload ![Located FieldDeclaration]
  deriving stock (Eq, Show)

{-| @Program.Syntax.Trait — declares a behavior contract without state -}
data Trait = Trait
  { traitVisibility :: !Visibility
  , traitName :: !(Located Text)
  , traitTypeParams :: ![Located TypeParam]
  , traitConstraints :: ![Located Constraint]
  , traitMembers :: ![Located Function]
  }
  deriving stock (Eq, Show)

{-| @Program.Syntax.Impl — implements one trait for one nominal type -}
data Impl = Impl
  { implTypeParams :: ![Located TypeParam]
  , implTrait :: !(Located TypeSyntax)
  , implTarget :: !(Located TypeSyntax)
  , implConstraints :: ![Located Constraint]
  , implFunctions :: ![Located Function]
  }
  deriving stock (Eq, Show)

{-| @Program.Syntax.Parameter — preserves function input syntax -}
data Parameter = Parameter
  { parameterName :: !(Located Text)
  , parameterType :: !(Maybe (Located TypeSyntax))
  , parameterDefault :: !(Maybe (Located Expression))
  }
  deriving stock (Eq, Show)

{-| @Type.Syntax.Reference — models unresolved type spelling -}
data TypeSyntax
  = NamedType !ModuleName ![Located TypeSyntax]
  | ReferenceType !Bool !(Located TypeSyntax)
  | TupleType ![Located TypeSyntax]
  | FunctionType !Bool ![Located TypeSyntax] !(Located TypeSyntax)
  | UnitType
  | InvalidType
  deriving stock (Eq, Show)

{-| @Program.Syntax.FunctionBody — distinguishes block and expression bodies -}
data FunctionBody
  = BlockBody !(Located Block)
  | ExpressionBody !(Located Expression)
  deriving stock (Eq, Show)

{-| @Program.Syntax.Block — orders statements and optional result -}
data Block = Block
  { blockStatements :: ![Located Statement]
  , blockResult :: !(Maybe (Located Expression))
  }
  deriving stock (Eq, Show)

{-| @Program.Syntax.Statement — models non-result block entries -}
data Statement
  = DeclarationStatement !(Located Declaration)
  | ExpressionStatement !(Located Expression)
  | ReturnStatement !(Maybe (Located Expression))
  | BreakStatement
  | ContinueStatement
  | InvalidStatement
  deriving stock (Eq, Show)

{-| @Program.Syntax.Literal — preserves unresolved literal values -}
data Literal
  = IntegerValue !Text
  | FloatValue !Text
  | StringValue !Text
  | CharValue !Char
  | BoolValue !Bool
  | NullValue
  deriving stock (Eq, Show)

{-| @Program.Syntax.Pattern — models match and binding-position patterns -}
data Pattern
  = WildcardPattern
  | BindingPattern !(Located Text)
  | LiteralPattern !Literal
  | RangePattern !Literal !Bool !Literal
  | TuplePattern ![Located Pattern]
  | ConstructorPattern !ModuleName ![Located Pattern]
  | RecordPattern !(Maybe ModuleName) ![Located FieldPattern] !Bool
  | AlternativePattern ![Located Pattern]
  | InvalidPattern
  deriving stock (Eq, Show)

{-| @Program.Syntax.FieldPattern — one record field pattern; an absent value
    binds the field to its own name. -}
data FieldPattern = FieldPattern
  { fieldPatternName :: !(Located Text)
  , fieldPatternValue :: !(Maybe (Located Pattern))
  }
  deriving stock (Eq, Show)

{-| @Program.Syntax.MatchArm — one `case` pattern, optional guard, and body -}
data MatchArm = MatchArm
  { armPattern :: !(Located Pattern)
  , armGuard :: !(Maybe (Located Expression))
  , armBody :: !(Located Expression)
  }
  deriving stock (Eq, Show)

{-| @Program.Syntax.Expression — models admitted expression forms -}
data Expression
  = LiteralExpression !Literal
  | NameExpression !(NonEmpty Text)
  | UnaryExpression !Text !(Located Expression)
  | BinaryExpression !(Located Expression) !Text !(Located Expression)
  | CallExpression !(Located Expression) ![Located Expression]
  | MemberExpression !(Located Expression) !(Located Text)
  | IndexExpression !(Located Expression) !(Located Expression)
  | TryExpression !(Located Expression)
  | AwaitExpression !(Located Expression)
  | TupleExpression ![Located Expression]
  | BlockExpression !(Located Block)
  | IfExpression !(Located Expression) !(Located Block) !(Maybe (Located Expression))
  | MatchExpression !(Located Expression) ![Located MatchArm]
  | WhileExpression !(Located Expression) !(Located Block)
  | LoopExpression !(Located Block)
  | ForExpression !(Located Pattern) !(Located Expression) !(Located Block)
  | InvalidExpression
  deriving stock (Eq, Show)
