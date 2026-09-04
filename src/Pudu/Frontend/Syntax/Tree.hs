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
  , requiredParameterCount
  , FunctionBody (..)
  , Foreign (..)
  , ForeignFunction (..)
  , ForeignParameter (..)
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
import Pudu.Frontend.Syntax.Located (Located, locatedValue)
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
  {-| A library written elsewhere, and the functions this program calls in it.

      Declared in a block because the library is what they share: it is opened
      once, its version is one fact, and what a program reaches outside itself
      is one place to look. -}
  | ForeignDeclaration !Foreign
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

{-| How many arguments a call of this function must supply.

    Its parameters, less the trailing ones that have defaults. Only a trailing
    run may be omitted: a default written before a parameter that has none
    cannot be skipped, because the next argument would take its place. -}
requiredParameterCount :: Function -> Int
requiredParameterCount value =
  length (dropWhile defaulted (reverse (functionParameters value)))
 where
  defaulted parameter = parameterDefault (locatedValue parameter) /= Nothing

{-| @Type.Syntax.TypeParam — one declared generic parameter and its bounds -}
data TypeParam = TypeParam
  { typeParamName :: !(Located Text)
  {-| How many type arguments the parameter takes.

      Zero is the ordinary parameter, standing for a type. A parameter written
      `F[_]` stands for a constructor of one argument, and may be applied to
      exactly that many. The arity is written rather than read from how the
      parameter is used, so the declaration says what the parameter is and a
      wrong application is reported where it is written. -}
  , typeParamArity :: !Int
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
  {-| A function that requires unchecked abilities of whoever calls it.

      Written as a prefix on the type rather than as part of the function
      arrow, so an ordinary signature stays exactly what it was and only the
      declarations that require something say so. -}
  | UnsafeType ![Located Capability] !(Located TypeSyntax)
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
{-| A library written elsewhere. -}
data Foreign = Foreign
  { foreignVisibility :: !Visibility
  , foreignLibrary :: !(Located Text)
  {-| The version the declaration expects, where it names one. Recorded rather
      than enforced: nothing here fetches or verifies a library, and claiming
      to check a version this cannot see would be worse than saying nothing. -}
  , foreignVersion :: !(Maybe (Located Text))
  {-| The opaque things this library hands back, named so a signature can say
      which one it means. A library's handles are not interchangeable — a window
      is not a texture — and one address type for all of them makes passing the
      wrong one a fault the library reports rather than one the checker does. -}
  , foreignTypes :: ![Located Text]
  , foreignFunctions :: ![Located ForeignFunction]
  }
  deriving stock (Eq, Show)

{-| One function in a foreign library, as this program asserts its shape.

    The assertion is unverifiable — a wrong width is a corrupted stack rather
    than a diagnostic — which is why reaching one needs `unsafe`. -}
data ForeignFunction = ForeignFunction
  { foreignName :: !(Located Text)
  {-| The exact symbol the library exports when it differs from the local
      value name. Tooling and calls keep the local name; only lookup reads this. -}
  , foreignSymbol :: !(Maybe (Located Text))
  , foreignParameters :: ![Located ForeignParameter]
  , foreignResult :: !(Located TypeSyntax)
  {-| The function that releases what this one returns, when what it returns
      must be released. A returned pointer is borrowed unless this names its
      release, so an owned value carries what frees it. -}
  , foreignReleasedBy :: !(Maybe (Located Text))
  }
  deriving stock (Eq, Show)

{-| One parameter of a foreign function.

    An ordinary parameter is a value the caller sends. An output slot is storage
    the boundary supplies and the library writes into: the caller sends nothing
    for it, and what the library left there comes back beside the result. Most C
    libraries hand back the resource they made this way, which is why the
    distinction is in the declaration rather than in a comment. -}
data ForeignParameter = ForeignParameter
  { foreignParameterName :: !(Located Text)
  , foreignParameterType :: !(Maybe (Located TypeSyntax))
  {-| Whether the library writes this parameter rather than reading it. -}
  , foreignParameterOut :: !Bool
  {-| What releases the handle an owned slot received, and whether the slot was
      written `owned` at all — a handle slot that is not owned is refused, so
      the two are recorded separately. -}
  , foreignParameterOwned :: !Bool
  , foreignParameterReleasedBy :: !(Maybe (Located Text))
  }
  deriving stock (Eq, Show)

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
  | SetExpression ![Located Expression]
  | UnsafeExpression ![Located Capability] !(Located Block)
  | MacroCall !(Located Text) ![Located Expression]
  | ScopeExpression !(Located Block)
  | LambdaExpression !Function
  | TypeApplication !(Located Expression) ![Located TypeSyntax]
  | RecordExpression !ModuleName ![Located FieldInit]
  {-| A record that is another record with some fields different.

      The language has no other way to say it, and without one, changing a
      single field of a ten-field record means writing the other nine out —
      which is not merely tedious: the nine that were copied are nine chances
      to copy one wrong, and a reader cannot see which field the expression is
      actually about. -}
  | RecordUpdateExpression !ModuleName !(Located Expression) ![Located FieldInit]
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
