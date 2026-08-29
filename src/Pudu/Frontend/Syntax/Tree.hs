{-| @Program.Syntax.Tree — models recoverable surface structure -}
module Pudu.Frontend.Syntax.Tree
  ( BindingKind (..)
  , Block (..)
  , Capability (..)
  , Constraint (..)
  , Declaration (..)
  , Expression (..)
  , FieldDeclaration (..)
  , FieldInit (..)
  , FieldPattern (..)
  , Function (..)
  , lambdaName
  , FunctionBody (..)
  , Impl (..)
  , Import (..)
  , Literal (..)
  , Macro (..)
  , MacroKind (..)
  , MacroParam (..)
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

{-| @Program.Syntax.Capability — one unchecked ability an unsafe context grants.

    The set is the one [[grammar/pudu]]'s unsafe boundary enumerates, so naming
    a capability says exactly which invariant the reader is taking on rather
    than switching every check off at once. -}
data Capability
  = RawCapability
  | ForeignCapability
  | UncheckedCapability
  | NullCapability
  deriving stock (Eq, Ord, Show, Enum, Bounded)

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
  | MacroDeclaration !Macro
  | InvalidDeclaration
  deriving stock (Eq, Show)

{-| @Program.Syntax.Function — carries one complete function signature. The body
    is absent only for a trait member that declares behavior without providing
    a default implementation. -}
data Function = Function
  { functionVisibility :: !Visibility
  , functionAsync :: !Bool
  , functionUnsafe :: !(Maybe [Located Capability])
  , functionComptime :: !Bool
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

{-| @Program.Syntax.Macro — a typed syntax transformer.

    Each parameter declares the kind of syntax it accepts, which is what lets a
    mismatch be reported against the call rather than against a matcher, and
    what lets the expander know which identifiers the body introduced. -}
data Macro = Macro
  { macroVisibility :: !Visibility
  , macroName :: !(Located Text)
  , macroParameters :: ![Located MacroParam]
  , macroBody :: !(Located Expression)
  }
  deriving stock (Eq, Show)

data MacroParam = MacroParam
  { macroParamName :: !(Located Text)
  , macroParamKind :: !MacroKind
  }
  deriving stock (Eq, Show)

{-| @Program.Syntax.MacroKind — the syntax a macro parameter accepts -}
data MacroKind
  = ExpressionKind
  | IdentifierKind
  | BlockKind
  deriving stock (Eq, Ord, Show, Enum, Bounded)

{-| The name a function literal is known by.

    Every closure carries a name for diagnostics and for `renderValue`, and a
    literal has none the reader wrote. This spelling cannot collide with a
    declared name, because an identifier cannot contain a space. -}
lambdaName :: Text
lambdaName = "<fn>"

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
  | DynamicType !ModuleName
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
  | BreakStatement !(Maybe (Located Text)) !(Maybe (Located Expression))
  | ContinueStatement !(Maybe (Located Text))
  {-| `let PATTERN = EXPRESSION else BLOCK`. The pattern binds for the rest of
      the enclosing block, which the fallback pays for by not being able to
      reach it. -}
  | LetElseStatement !(Located Pattern) !(Located Expression) !(Located Block)
  | InvalidStatement
  deriving stock (Eq, Show)

{-| @Program.Syntax.Literal — preserves unresolved literal values -}
data Literal
  = IntegerValue !Text
  | FloatValue !Text
  | DecimalValue !Text
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

{-| @Program.Syntax.FieldInit — one field of a record construction; an absent
    value takes the binding with the field's own name. -}
data FieldInit = FieldInit
  { fieldInitName :: !(Located Text)
  , fieldInitValue :: !(Maybe (Located Expression))
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
  | ArrayExpression ![Located Expression]
  | UnsafeExpression ![Located Capability] !(Located Block)
  | MacroCall !(Located Text) ![Located Expression]
  | ScopeExpression !(Located Block)
  | LambdaExpression !Function
  | TypeApplication !(Located Expression) ![Located TypeSyntax]
  | RecordExpression !ModuleName ![Located FieldInit]
  | BlockExpression !(Located Block)
  | IfExpression !(Located Expression) !(Located Block) !(Maybe (Located Expression))
  | IfLetExpression !(Located Pattern) !(Located Expression) !(Located Block)
      !(Maybe (Located Expression))
  | MatchExpression !(Located Expression) ![Located MatchArm]
  | WhileExpression !(Maybe (Located Text)) !(Located Expression) !(Located Block)
  {-| `while let PATTERN = EXPRESSION BLOCK`. The subject is read again before
      each turn and the loop ends the first time the pattern does not match. -}
  | WhileLetExpression
      !(Maybe (Located Text))
      !(Located Pattern)
      !(Located Expression)
      !(Located Block)
  | LoopExpression !(Maybe (Located Text)) !(Located Block)
  | ForExpression !(Maybe (Located Text)) !(Located Pattern) !(Located Expression) !(Located Block)
  | InvalidExpression
  deriving stock (Eq, Show)
