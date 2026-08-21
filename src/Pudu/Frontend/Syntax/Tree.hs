{-| @Program.Syntax.Tree — models recoverable surface structure -}
module Pudu.Frontend.Syntax.Tree
  ( BindingKind (..)
  , Block (..)
  , Declaration (..)
  , Expression (..)
  , FunctionBody (..)
  , Import (..)
  , Literal (..)
  , Module (..)
  , Parameter (..)
  , Statement (..)
  , TypeSyntax (..)
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

{-| @Program.Syntax.Declaration — models initial declaration forms -}
data Declaration
  = BindingDeclaration
      !Visibility
      !BindingKind
      !(Located Text)
      !(Maybe (Located TypeSyntax))
      !(Located Expression)
  | FunctionDeclaration
      !Visibility
      !Bool
      !(Located Text)
      ![Located Parameter]
      !(Maybe (Located TypeSyntax))
      !(Located FunctionBody)
  | InvalidDeclaration
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

{-| @Program.Syntax.Expression — models initial expression forms -}
data Expression
  = LiteralExpression !Literal
  | NameExpression !(NonEmpty Text)
  | UnaryExpression !Text !(Located Expression)
  | BinaryExpression !(Located Expression) !Text !(Located Expression)
  | CallExpression !(Located Expression) ![Located Expression]
  | MemberExpression !(Located Expression) !(Located Text)
  | BlockExpression !(Located Block)
  | IfExpression !(Located Expression) !(Located Block) !(Maybe (Located Expression))
  | InvalidExpression
  deriving stock (Eq, Show)
