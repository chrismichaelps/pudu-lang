{-| @Pudu.Core.Module — the checked, span-carrying module the native backend
    consumes.

    This is the concrete form of the vault's Core IR for the native path: no
    unresolved names, no surface sugar, no target syntax. Every statement and
    expression is a record whose first field is the span it came from, locals
    carry their identity, name, and type together, and the value forms of `if`
    and blocks make a branch without a result unrepresentable. Nothing here
    executes, renders, or refuses; [[Pudu.Compiler.Lower]] produces it and
    [[Pudu.Backend.Emit]] translates it.
-}
module Pudu.Core
  ( CoreBinaryOperator (..)
  , CoreBlock (..)
  , CoreExpression (..)
  , CoreExpressionShape (..)
  , CoreFunction (..)
  , CoreLoopId (..)
  , CoreLocal (..)
  , CoreModule (..)
  , CoreParameter (..)
  , CoreStatement (..)
  , CoreStatementShape (..)
  , CoreTextMethodName (..)
  , CoreType (..)
  , coreTypeName
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Data.Word (Word64)
import Pudu.FloatLiteral (FloatWidth, floatWidthType)
import Pudu.IntegerLiteral (IntegerKind, integerKindName)
import Pudu.Source (Span)

{-| @Core.Module — one compiled program: its name, the entry function the
    process enters, and the functions reachable from it. -}
data CoreModule = CoreModule
  { coreModuleName :: !Text
  , coreModuleEntry :: !Text
  , coreModuleFunctions :: ![CoreFunction]
  }
  deriving stock (Eq, Show)

{-| @Core.Function — a lowered function: its name, parameters, result type,
    and body. -}
data CoreFunction = CoreFunction
  { coreFunctionName :: !Text
  , coreFunctionParameters :: ![CoreParameter]
  , coreFunctionResult :: !CoreType
  , coreFunctionBody :: !CoreBlock
  }
  deriving stock (Eq, Show)

{-| @Core.Parameter — a named, typed parameter slot. -}
data CoreParameter = CoreParameter
  { coreParameterLocal :: !CoreLocal
  , coreParameterSpan :: !Span
  }
  deriving stock (Eq, Show)

{-| @Core.Block — ordered statements and an optional trailing result. -}
data CoreBlock = CoreBlock
  { coreBlockStatements :: ![CoreStatement]
  , coreBlockResult :: !(Maybe CoreExpression)
  }
  deriving stock (Eq, Show)

{-| @Core.Local — one binding: its identity, the name it was written under,
    and its type. Shadowing is distinct identities, never distinct names. -}
data CoreLocal = CoreLocal
  { coreLocalId :: !Int
  , coreLocalName :: !Text
  , coreLocalType :: !CoreType
  }
  deriving stock (Eq, Show)

{-| @Core.Statement — a span and its shape. -}
data CoreStatement = CoreStatement
  { coreStatementSpan :: !Span
  , coreStatementShape :: !CoreStatementShape
  }
  deriving stock (Eq, Show)

{-| Function-local loop destination; lowering resolves source labels once. -}
newtype CoreLoopId = CoreLoopId Int
  deriving stock (Eq, Ord, Show)

{-| @Core.StatementShape — the statement forms the native subset carries.

    `CoreIf`'s else branch is an expression so a chained `else if` stays one
    node; when present in statement position the branch's value is evaluated
    and discarded, because a discarded checked expression can still abort. -}
data CoreStatementShape
  = CoreDeclare !CoreLocal !CoreExpression
  | CoreAssign !CoreLocal !CoreExpression
  | CoreEvaluate !CoreExpression
  | CoreIf !CoreExpression !CoreBlock !(Maybe CoreExpression)
  | CoreReturn !(Maybe CoreExpression)
  | CoreBreak !CoreLoopId !(Maybe CoreExpression)
  | CoreContinue !CoreLoopId
  deriving stock (Eq, Show)

{-| @Core.Expression — a span, its checked type, and its shape. The type is
    carried here, not recomputed, so the emitter never guesses and the
    interpreter's checking and the backend's reading cannot drift. -}
data CoreExpression = CoreExpression
  { coreExpressionSpan :: !Span
  , coreExpressionType :: !CoreType
  , coreExpressionShape :: !CoreExpressionShape
  }
  deriving stock (Eq, Show)

{-| @Core.ExpressionShape — the expression forms the native subset carries.

    `CoreTextLiteral`, `CoreDisplay` and `CoreShow` have type `CoreTextType`,
    an ordinary value type; `CoreAdd` of two texts concatenates.
    `CoreIfValue` requires an else branch by construction. `CoreCall` names
    its callee and carries its arguments in source order, which is the
    evaluator's evaluation order; C does not guarantee one, so the emitter
    sequences the arguments itself. -}
data CoreExpressionShape
  = CoreIntegerLiteral !IntegerKind !Integer
  {-| The binary64 encoding the literal parsed to; Float32 is already narrowed. -}
  | CoreFloatLiteral !FloatWidth !Word64
  | CoreBoolLiteral !Bool
  | CoreTextLiteral !Text
  | CoreCharLiteral !Char
  | CoreReadLocal !CoreLocal
  | CoreNegate !CoreExpression
  | CoreComplement !CoreExpression
  | CoreNot !CoreExpression
  | CoreBinary !CoreBinaryOperator !CoreExpression !CoreExpression
  | CoreDisplay !CoreExpression
  {-| `renderValue` text: Str gains quotes and escapes, scalars read as display. -}
  | CoreShow !CoreExpression
  {-| A built-in Str method; the arguments run before the receiver. -}
  | CoreTextMethod !CoreTextMethodName !CoreExpression ![CoreExpression]
  {-| `c.code()`: the scalar as an Int. -}
  | CoreCharCode !CoreExpression
  {-| Members in source order, which is the order they run. -}
  | CoreTuple ![CoreExpression]
  {-| A literal position the checker has already bounded. -}
  | CoreTupleIndex !Int !CoreExpression
  {-| Fields as written, which is the order they run; the record holds them
      in declaration order. -}
  | CoreRecord ![(Text, CoreExpression)]
  {-| `base` with the written fields replaced; base runs first. -}
  | CoreRecordUpdate !CoreExpression ![(Text, CoreExpression)]
  | CoreField !Text !CoreExpression
  | CorePrint !CoreExpression
  | CoreCall !Text ![CoreExpression]
  {-| Operands finish in order before E7001; this expression never returns. -}
  | CoreOperatorFailure !Text ![CoreExpression]
  | CoreBlockValue !CoreBlock
  | CoreIfValue !CoreExpression !CoreBlock !CoreExpression
  | CoreWhileValue !CoreLoopId !CoreExpression !CoreBlock
  | CoreLoopValue !CoreLoopId !CoreBlock
  deriving stock (Eq, Show)

{-| The Str methods native implements, named as the evaluator names them. -}
data CoreTextMethodName
  = TextLength
  | TextIsEmpty
  | TextContains
  | TextStartsWith
  | TextEndsWith
  | TextIndexOf
  | TextSpanOf
  | TextSpanNotOf
  | TextDrop
  | TextTake
  | TextSlice
  | TextRepeat
  | TextReverse
  | TextEscapeHtml
  | TextReplace
  | TextTrim
  | TextToUpper
  | TextToLower
  | TextCharAt
  deriving stock (Eq, Show)

{-| @Core.BinaryOperator — the operator vocabulary, already resolved from
    source spelling; no operator text survives into the backend. -}
data CoreBinaryOperator
  = CoreAdd
  | CoreSubtract
  | CoreMultiply
  | CoreDivide
  | CoreRemainder
  | CoreBitAnd
  | CoreBitOr
  | CoreBitXor
  | CoreShiftLeft
  | CoreShiftRight
  | CoreWrapAdd
  | CoreWrapSubtract
  | CoreWrapMultiply
  | CoreSaturateAdd
  | CoreSaturateSubtract
  | CoreSaturateMultiply
  | CoreLess
  | CoreLessOrEqual
  | CoreGreater
  | CoreGreaterOrEqual
  | CoreEqual
  | CoreNotEqual
  | CoreAnd
  | CoreOr
  deriving stock (Eq, Show)

{-| Runtime types and divergence. CorePrint is effect-only; its
    surface Result must never escape as a Core unit value. -}
data CoreType
  = CoreIntegerType !IntegerKind
  | CoreFloatType !FloatWidth
  | CoreBoolType
  | CoreTextType
  | CoreCharType
  | CoreTupleType ![CoreType]
  {-| A record of the root module: its name and its fields in declaration order. -}
  | CoreRecordType !Text ![(Text, CoreType)]
  | CoreUnitType
  | CoreNeverType
  deriving stock (Eq, Show)

coreTypeName :: CoreType -> Text
coreTypeName coreType = case coreType of
  CoreIntegerType kind -> integerKindName kind
  CoreFloatType width -> floatWidthType width
  CoreBoolType -> "Bool"
  CoreTextType -> "Str"
  CoreCharType -> "Char"
  CoreTupleType members -> "(" <> Text.intercalate ", " (map coreTypeName members) <> ")"
  CoreRecordType name _ -> name
  CoreUnitType -> "Unit"
  CoreNeverType -> "Never"
