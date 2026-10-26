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
  , CoreArm (..)
  , CoreClosureInfo (..)
  , CoreLayout (..)
  , CoreLocal (..)
  , CoreModule (..)
  , CorePattern (..)
  , CoreVariant (..)
  , CoreParameter (..)
  , CoreStatement (..)
  , CoreStatementShape (..)
  , CoreTextMethodName (..)
  , CoreArrayMethodName (..)
  , CoreKeyedMethodName (..)
  , CoreType (..)
  , coreTypeName
  , displayName
  ) where

import Data.Map.Strict (Map)
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
  {-| How each record and sum the functions mention is laid out. Types name
      records and sums only by identity, so recursive ones stay finite. -}
  , coreModuleLayouts :: !(Map CoreType CoreLayout)
  {-| Every function a closure can run, by its key. -}
  , coreModuleClosures :: !(Map Text CoreClosureInfo)
  }
  deriving stock (Eq, Show)

{-| What a closure over a lifted function holds and how it reads: the types
    of its captures in cell order, the name `<fn name>` renders, and the place
    it was written. Two closures are equal when they were written in the same
    place, as the evaluator's closures are. -}
data CoreClosureInfo = CoreClosureInfo
  { closureCaptures :: ![CoreType]
  , closureDisplayName :: !Text
  , closureSite :: !Text
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
  {-| Whether an integer lies inside the kind's bounds. -}
  | CoreIntegerFits !IntegerKind !CoreExpression
  {-| The same integer at the kind; only built where it fits. -}
  | CoreIntegerConvert !IntegerKind !CoreExpression
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
  {-| A variant and its payload fields as written (positional payloads are
      named "0", "1", ...); the sum holds them in declaration order. -}
  | CoreConstruct !Text ![(Text, CoreExpression)]
  {-| The subject runs once, then each arm is tried in order. -}
  | CoreMatch !CoreExpression ![CoreArm]
  {-| Ends the program with a diagnostic whose text is only known now. The
      last operand, when there is one, is help text computed the same way and
      it replaces the written help. -}
  | CoreFailText !Text !(Maybe Text) !CoreExpression !(Maybe CoreExpression)
  {-| The name of the variant a sum value holds, as text. -}
  | CoreVariantName !CoreExpression
  | CorePrint !CoreExpression
  | CoreCall !Text ![CoreExpression]
  {-| A closure over the lifted function with this key, holding these values. -}
  | CoreClosure !Text ![CoreExpression]
  {-| Capture number i of the closure the operand reads. -}
  | CoreCapture !Int !CoreExpression
  {-| A call through a function value: the callee runs, then the arguments. -}
  | CoreCallValue !CoreExpression ![CoreExpression]
  {-| Members in source order, which is the order they run. -}
  | CoreArray ![CoreExpression]
  {-| A built-in array method; the arguments run before the receiver. -}
  | CoreArrayMethod !CoreArrayMethodName !CoreExpression ![CoreExpression]
  {-| A map or set operation; the arguments run before the receiver. -}
  | CoreKeyedMethod !CoreKeyedMethodName !CoreExpression ![CoreExpression]
  {-| Whether a value can be ordered, as `comparableValue` answers. -}
  | CoreComparable !CoreExpression
  {-| `array[index]`: the array, then the index. The expression's span is the
      index's, where an index out of range reports. -}
  | CoreIndex !CoreExpression !CoreExpression
  {-| The local's value, leaving the local empty: the read is its last before
      it is assigned again, so a uniquely held buffer stays unique. -}
  | CoreTakeLocal !CoreLocal
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
  | TextSplit
  | TextLines
  | TextChars
  {-| `toInt` and `toFloat` come apart into a test and a read, so lowering
      can build the Option itself. -}
  | TextParsesInt
  | TextIntOf
  | TextParsesFloat
  | TextFloatOf
  deriving stock (Eq, Show)

{-| The array methods native implements in the runtime, named as the
    evaluator names them; map, filter and reduce lower to loops instead. -}
data CoreArrayMethodName
  = ArrayLengthOf
  | ArrayIsEmptyOf
  | ArrayGetAt
  | ArrayIndexOfValue
  | ArrayContainsValue
  | ArrayPushValue
  | ArrayPopLast
  | ArrayInsertAt
  | ArrayRemoveAt
  | ArraySliceOf
  | ArrayConcatWith
  | ArrayJoinWith
  | ArrayReversed
  deriving stock (Eq, Show)

{-| What the runtime does for maps and sets. `KeyedLookup` reads a value
    `KeyedContains` has already found; `KeyedFromArray`'s receiver is the array
    of pairs or members it builds from; a set's `toArray` is `KeyedKeys`. -}
data CoreKeyedMethodName
  = KeyedSize
  | KeyedIsEmpty
  | KeyedContains
  | KeyedLookup
  | KeyedInsert
  | KeyedRemove
  | KeyedKeys
  | KeyedValues
  | KeyedEntries
  | KeyedMerge
  | KeyedUnion
  | KeyedIntersect
  | KeyedDifference
  | KeyedFromArray
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
  {-| A record, by its canonical key and its type arguments; its fields are
      its layout. Box[Int] and Box[Str] are different layouts. -}
  | CoreRecordType !Text ![CoreType]
  {-| A sum at concrete type arguments: Option[Int] and Option[Str] differ. -}
  | CoreSumType !Text ![CoreType]
  {-| An array: a box holding a growable buffer of items of one type. -}
  | CoreArrayType !CoreType
  {-| A map or set: a box holding the root of a shared balanced tree. -}
  | CoreMapType !CoreType !CoreType
  | CoreSetType !CoreType
  {-| A function value: a closure box whose first cell names what it runs. -}
  | CoreFunctionType ![CoreType] !CoreType
  | CoreUnitType
  | CoreNeverType
  deriving stock (Eq, Ord, Show)

coreTypeName :: CoreType -> Text
coreTypeName coreType = case coreType of
  CoreIntegerType kind -> integerKindName kind
  CoreFloatType width -> floatWidthType width
  CoreBoolType -> "Bool"
  CoreTextType -> "Str"
  CoreCharType -> "Char"
  CoreTupleType members -> "(" <> Text.intercalate ", " (map coreTypeName members) <> ")"
  CoreRecordType name [] -> displayName name
  CoreRecordType name arguments -> displayName name <> "[" <> Text.intercalate ", " (map coreTypeName arguments) <> "]"
  CoreSumType name [] -> displayName name
  CoreSumType name arguments -> displayName name <> "[" <> Text.intercalate ", " (map coreTypeName arguments) <> "]"
  CoreArrayType element -> "Array[" <> coreTypeName element <> "]"
  CoreMapType key value -> "Map[" <> coreTypeName key <> ", " <> coreTypeName value <> "]"
  CoreSetType member -> "Set[" <> coreTypeName member <> "]"
  CoreFunctionType inputs result -> "fn(" <> Text.intercalate ", " (map coreTypeName inputs) <> ") -> " <> coreTypeName result
  CoreUnitType -> "Unit"
  CoreNeverType -> "Never"

{-| A record or sum as a program writes it: the last segment of its canonical
    key (`Main.Point` is `Point`), which is how the evaluator renders it. -}
displayName :: Text -> Text
displayName key = case Text.splitOn "." key of
  [] -> key
  segments -> last segments

{-| A record's fields, or a sum's variants, in declaration order. -}
data CoreLayout
  = CoreRecordLayout ![(Text, CoreType)]
  | CoreSumLayout ![CoreVariant]
  {-| A function type's closures: every lifted function a value of it can
      run, by key, with what its box holds. -}
  | CoreClosureLayout ![(Text, CoreClosureInfo)]
  deriving stock (Eq, Show)

{-| One variant: its name, payload types, and whether the payload is a
    record's fields or positions (named "0", "1", ...). -}
data CoreVariant = CoreVariant
  { coreVariantName :: !Text
  , coreVariantFields :: ![(Text, CoreType)]
  , coreVariantRecord :: !Bool
  }
  deriving stock (Eq, Show)

{-| One `case`: its pattern, the locals the pattern binds, the guard, and the
    arm's value. -}
data CoreArm = CoreArm
  { coreArmSpan :: !Span
  , coreArmPattern :: !CorePattern
  , coreArmGuard :: !(Maybe CoreExpression)
  , coreArmBody :: !CoreExpression
  }
  deriving stock (Eq, Show)

{-| Patterns against the type the checker gave the subject. A variant
    pattern lists its payload in declaration order, filling unnamed record
    fields with wildcards. -}
data CorePattern
  = CoreWildcardPattern
  | CoreBindPattern !CoreLocal
  | CoreLiteralPattern !CoreExpression
  | CoreRangePattern !CoreExpression !Bool !CoreExpression
  | CoreTuplePattern ![CorePattern]
  | CoreRecordPattern ![CorePattern]
  | CoreVariantPattern !Text ![CorePattern]
  | CoreAlternativePattern ![CorePattern]
  {-| `[a, ..rest, z]`: items read from the front, then the rest (absent,
      skipped, or bound to a local), then items read from the back. -}
  | CoreArrayPattern ![CorePattern] !(Maybe (Maybe CoreLocal)) ![CorePattern]
  deriving stock (Eq, Show)
