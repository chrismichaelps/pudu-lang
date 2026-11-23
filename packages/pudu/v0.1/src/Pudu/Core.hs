{-| @Pudu.Core.Module — the checked, span-carrying module the native backend
    consumes.

    This is the concrete form of the vault's Core IR for the native path: no
    unresolved names, no surface sugar, no target syntax. Every statement and
    expression is a record whose first field is the span it came from, locals
    carry their identity, name, and type together, and the value forms of `if`
    and blocks make a branch without a result unrepresentable. Nothing here
    executes, renders, or refuses; [[Pudu.Compiler.Lower]] produces it and
    [[Pudu.Backend.Emit]] translates it. -}
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
  , CoreTextMethodName (..), CoreArrayMethodName (..), CoreKeyedMethodName (..)
  , CoreRangeMethodName (..), CoreBytesMethodName (..), CoreDecimalMethodName (..)
  , CoreKernelName (..)
  , CoreForeign (..), CoreClaim (..)
  , CoreCallbackOperation (..), CoreDelegate (..), CoreCallbackSignature (..), CoreCallbackFallback (..), CoreCallbackSlot (..)
  , CoreType (..)
  , coreTypeName, coreStaticRuntimeKind, displayName, suppliedCountName
  , runtimeChoiceKey, runtimeChoiceAlternatives
  , recordCarrier, recordCarrierParts
  , sumCarrier, sumCarrierParts
  ) where

import Data.ByteString (ByteString)
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Word (Word64)
import Pudu.FloatLiteral (FloatWidth, floatWidthType)
import Pudu.Foreign.Callback (CallbackPlacement)
import Pudu.Foreign.Crossing (ObjectiveCMethod)
import Pudu.Foreign.Extent (ForeignBound)
import Pudu.IntegerLiteral (IntegerKind, integerKindName)
import Pudu.Source (Span)
import Pudu.Core.Bytes (CoreBytesMethodName (..))
import Pudu.Core.TextMethod (CoreTextMethodName (..))
import Pudu.Core.Keyed (CoreKeyedMethodName (..))
import Pudu.Core.Kernel (CoreKernelName (..))

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
  {-| Keys of the root module's exported functions a library build lowered,
      in declaration order; empty for an executable. -}
  , coreModuleExports :: ![Text]
  }
  deriving stock (Eq, Show)

{-| A callable's captures, displayed name and source identity. Lifted bodies
    also take the callable as a hidden first parameter. -}
data CoreClosureInfo = CoreClosureInfo
  { closureCaptures :: ![CoreType]
  , closureDisplayName :: !Text
  , closureSite :: !Text
  , closureIsBuiltin :: !Bool
  , closureHasEnvironment :: !Bool
    -- | A built-in method taken as a value: the receiver's type. The receiver
    -- is capture 0, and it takes part in equality.
  , closureMethod :: !(Maybe CoreType)
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
  {-| A Decimal: its coefficient and its non-negative scale. -}
  | CoreDecimalLiteral !Integer !Int
  | CoreBoolLiteral !Bool
  | CoreTextLiteral !Text
  {-| Bytes known before the run, of type `CoreBytesType`. -}
  | CoreBytesLiteral !ByteString
  | CoreCharLiteral !Char
  {-| The zero of the expression's type, standing for an argument the call
      left to its default. The callee replaces it before anything reads it. -}
  | CoreAbsent
  | CoreReadLocal !CoreLocal
  | CoreNegate !CoreExpression
  | CoreComplement !CoreExpression
  | CoreNot !CoreExpression
  | CoreBinary !CoreBinaryOperator !CoreExpression !CoreExpression
  | CoreDisplay !CoreExpression
  {-| `renderValue` text: Str gains quotes and escapes, scalars read as display. -}
  | CoreShow !CoreExpression
  {-| A built-in Str method; the receiver runs before the arguments. -}
  | CoreTextMethod !CoreTextMethodName !CoreExpression ![CoreExpression]
  {-| `c.code()`: the scalar as an Int. -}
  | CoreCharCode !CoreExpression
  {-| Whether an integer lies inside the kind's bounds. -}
  | CoreIntegerFits !IntegerKind !CoreExpression
  {-| The Char with this code, once it is known to be a scalar value. -}
  | CoreCharOfCode !CoreExpression
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
  {-| Same, but pointing at the value call that entered this function. Only
      builtin bodies use it: the interpreter blames the call, not the body. -}
  | CoreFailCaller !Text !(Maybe Text) !CoreExpression
  {-| The name of the variant a sum value holds, as text. -}
  | CoreRuntimeKind !CoreExpression
  | CorePrint !CoreExpression
  {-| An ordered standard-stream write: error text, empty on success. -}
  | CoreOutputError !Bool !Bool !CoreExpression
  | CoreCall !Text ![CoreExpression]
  {-| A closure over the lifted function with this key, holding these values. -}
  | CoreClosure !Text ![CoreExpression]
  {-| Capture number i of the closure the operand reads. -}
  | CoreCapture !Int !CoreExpression
  | CoreClosureIs !Text !CoreExpression
  {-| A call through a function value: the callee runs, then the arguments. -}
  | CoreCallValue !CoreExpression ![CoreExpression]
  {-| Members in source order, which is the order they run. -}
  | CoreArray ![CoreExpression]
  {-| A built-in array method; the receiver runs before the arguments. -}
  | CoreArrayMethod !CoreArrayMethodName !CoreExpression ![CoreExpression]
  {-| A map or set operation; the receiver runs before the arguments. -}
  | CoreKeyedMethod !CoreKeyedMethodName !CoreExpression ![CoreExpression]
  {-| Whether a value can be ordered, as `comparableValue` answers. -}
  | CoreComparable !CoreExpression
  {-| A range from the ends written, the start running first. -}
  | CoreRangeValue !(Maybe CoreExpression) !Bool !(Maybe CoreExpression)
  {-| A range operation; the receiver runs before the arguments. -}
  | CoreRangeMethod !CoreRangeMethodName !CoreExpression ![CoreExpression]
  {-| A byte-sequence operation; the receiver runs before the arguments. -}
  | CoreBytesMethod !CoreBytesMethodName !CoreExpression ![CoreExpression]
  | CoreDecimalMethod !CoreDecimalMethodName ![CoreExpression]
  {-| A runtime kernel over operands in order, then its layout integers. -}
  | CoreKernel !CoreKernelName ![Int] ![CoreExpression]
  {-| A call to a foreign function, its arguments in order. -}
  | CoreForeignCall !CoreForeign ![CoreExpression]
  | CoreForeignSettle
  | CoreCallback !CoreCallbackOperation !CoreExpression
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

{-| The array methods native implements in the runtime, named as the
    evaluator names them; map, filter and reduce lower to loops instead. -}
data CoreArrayMethodName
  = ArrayLengthOf
  | ArrayIsEmptyOf
  | ArrayGetAt
  {-| The array with one element replaced: index, then the new element. -}
  | ArrayReplaceAt
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

{-| Range queries and materializers. `RangeValuesFor` names its method
    when a missing endpoint prevents materialization. -}
data CoreRangeMethodName
  = RangeLengthOf
  | RangeIsEmptyOf
  | RangeContainsValue
  | RangeHasStart
  | RangeStartExact
  | RangeHasEnd
  | RangeEndExact
  | RangeIsInclusiveOf
  | RangeIsBoundedOf
  | RangeMembersFitInt
  | RangeValuesFor !Text
  | RangeReversedOf
  | RangeStepBy
  | RangeSumOf
  deriving stock (Eq, Show)

{-| What the runtime does for byte sequences. `BytesOfArray` and
    `BytesFromText` build one from their receiver; `BytesAtIndex` and
    `BytesAsText` read what a test has already allowed. -}
{-| What the runtime does for Decimal beyond its operators. Each answers a
    plain value; the primitives that answer an Option are built from a test
    and a conversion the test allows, as `Std.Decimal` reads them. -}
data CoreDecimalMethodName
  = DecimalParses
  | DecimalParse
  | DecimalTextParses
  | DecimalFromInt
  | DecimalScaleOf
  | DecimalNamesInt
  | DecimalToInt
  | DecimalToFloat
  | DecimalDivideWith
  | DecimalRoundTo
  | DecimalIsZero
  deriving stock (Eq, Show)

{-| A foreign function as a native call names it: the library and version it
    opens, the symbol it resolves, and the crossing types of its parameters
    and result. -}
data CoreForeign = CoreForeign
  { coreForeignLibrary :: !Text
  , coreForeignVersion :: !(Maybe Text)
  , coreForeignSymbol :: !Text
  , coreForeignObjectiveC :: !(Maybe ObjectiveCMethod)
  , coreForeignParameters :: ![CoreType]
  , coreForeignResult :: !CoreType
    -- | What a handle result transfers, when the result is a handle.
  , coreForeignClaim :: !(Maybe CoreClaim)
    -- | Whether the function releases the handle it takes.
  , coreForeignReleases :: !Bool
  , coreForeignSlotPositions :: ![Int]
  , coreForeignSlotClaims :: ![Maybe CoreClaim]
  , coreForeignCallbacks :: ![CoreCallbackSlot]
  , coreForeignCanReenter :: !Bool
  , coreForeignLoans :: ![(Int, Bool)]
  , coreForeignAbsentLoans :: ![Int]
  , coreForeignBounds :: ![ForeignBound]
  , coreForeignReturnedRun :: !(Maybe (Int, CoreType))
  }
  deriving stock (Eq, Ord, Show)

data CoreCallbackOperation
  = CoreCallbackRegister !CoreCallbackSignature
  | CoreCallbackRegisterGroup !CoreCallbackSignature ![Int]
  | CoreCallbackUnregister
  | CoreDelegateNew !CoreDelegate
  deriving stock (Eq, Ord, Show)

{-| An Objective-C class defined at run time: its name, the callback group
    whose token an instance carries, and each method's selector with the
    group member's signature it enters. -}
data CoreDelegate = CoreDelegate
  { coreDelegateClass :: !Text
  , coreDelegateGroup :: !CoreCallbackSignature
  , coreDelegateMethods :: ![(Text, CoreCallbackSignature)]
  }
  deriving stock (Eq, Ord, Show)

{-| A trampoline's type and native slot sequence. Nothing identifies its
    context argument. The fallback refers to the declared result carrier. -}
data CoreCallbackSignature = CoreCallbackSignature
  { coreCallbackOwner :: !Text
  , coreCallbackArguments :: ![Maybe CoreType]
  , coreCallbackResult :: !CoreType
  , coreCallbackFallback :: !CoreCallbackFallback
  , coreCallbackByteLengths :: ![(Int, Int)]
  , coreCallbackProjection :: !(Maybe (Int, Text))
  }
  deriving stock (Eq, Ord, Show)

data CoreCallbackFallback
  = CallbackFallbackUnit
  | CallbackFallbackInteger !Integer
  | CallbackFallbackFloat !Word64
  | CallbackFallbackBool !Bool
  deriving stock (Eq, Ord, Show)

{-| Native argument indexes, including output slots and the callback context. -}
data CoreCallbackSlot = CoreCallbackSlot
  { coreCallbackPlacement :: !CallbackPlacement
  , coreCallbackSignature :: !CoreCallbackSignature
  }
  deriving stock (Eq, Ord, Show)

{-| A handle result is borrowed, or owned (each result its own claim, or one
    claim per reference when counted) and released by a function of the same
    library: its symbol and its result type. -}
data CoreClaim = CoreBorrowed | CoreOwned !Bool !Text !CoreType
  deriving stock (Eq, Ord, Show)

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
  {-| A map, set or Int-keyed store: a box holding a shared balanced tree's root. -}
  | CoreMapType !CoreType !CoreType
  | CoreSetType !CoreType
  | CoreStoreType !CoreType
  {-| A range of Ints: its optional ends and whether the end is included. -}
  | CoreRangeType
  {-| A byte sequence: a box around a view of counted storage. -}
  | CoreBytesType
  | CoreDecimalType
  {-| A function value: a closure box whose first cell names what it runs. -}
  | CoreFunctionType ![CoreType] !CoreType
  | CoreUnitType
  | CoreNeverType
  {-| An opaque handle a foreign library hands back: its canonical name, then
      the name it renders under. -}
  | CoreHandleType !Text !Text
  | CoreCallbackType !Text !Text
  deriving stock (Eq, Ord, Show)

runtimeChoiceKey :: Text
runtimeChoiceKey = "_runtime_choice"

runtimeChoiceAlternatives :: CoreType -> Maybe [(Text, CoreType)]
runtimeChoiceAlternatives (CoreSumType key members)
  | key == runtimeChoiceKey = Just (zip (map (Text.pack . show) [0 :: Int ..]) members)
runtimeChoiceAlternatives _ = Nothing

recordCarrier :: Text -> [CoreType] -> [CoreType] -> CoreType
recordCarrier owner arguments fields =
  CoreRecordType owner (CoreSumType "_runtime_record_fields" fields : arguments)

recordCarrierParts :: [CoreType] -> ([CoreType], Maybe [CoreType])
recordCarrierParts (CoreSumType "_runtime_record_fields" fields : arguments) = (arguments, Just fields)
recordCarrierParts arguments = (arguments, Nothing)

sumCarrier :: Text -> [CoreType] -> [CoreType] -> CoreType
sumCarrier owner arguments payload =
  CoreSumType owner (CoreSumType "_runtime_sum_payload" payload : arguments)

sumCarrierParts :: [CoreType] -> ([CoreType], Maybe [CoreType])
sumCarrierParts (CoreSumType "_runtime_sum_payload" payload : arguments) = (arguments, Just payload)
sumCarrierParts arguments = (arguments, Nothing)

coreTypeName :: CoreType -> Text
coreTypeName coreType = case coreType of
  CoreIntegerType kind -> integerKindName kind
  CoreFloatType width -> floatWidthType width
  CoreBoolType -> "Bool"
  CoreTextType -> "Str"
  CoreCharType -> "Char"
  CoreTupleType members -> "(" <> Text.intercalate ", " (map coreTypeName members) <> ")"
  CoreRecordType name native -> case fst (recordCarrierParts native) of
    [] -> displayName name
    arguments -> displayName name <> "[" <> Text.intercalate ", " (map coreTypeName arguments) <> "]"
  CoreSumType name native -> case fst (sumCarrierParts native) of
    [] -> displayName name
    arguments -> displayName name <> "[" <> Text.intercalate ", " (map coreTypeName arguments) <> "]"
  CoreArrayType element -> "Array[" <> coreTypeName element <> "]"
  CoreMapType key value -> "Map[" <> coreTypeName key <> ", " <> coreTypeName value <> "]"
  CoreSetType member -> "Set[" <> coreTypeName member <> "]"
  CoreStoreType held -> "Buckets[" <> coreTypeName held <> "]"
  CoreRangeType -> "Range[Int]"
  CoreBytesType -> "Bytes"
  CoreDecimalType -> "Decimal"
  CoreFunctionType inputs result -> "fn(" <> Text.intercalate ", " (map coreTypeName inputs) <> ") -> " <> coreTypeName result
  CoreUnitType -> "Unit"
  CoreNeverType -> "Never"
  CoreHandleType _ name -> name
  CoreCallbackType _ name -> name

{-| The diagnostic label for a value whose shape is fixed by its carrier. -}
coreStaticRuntimeKind :: CoreType -> Text
coreStaticRuntimeKind CoreUnitType = "unit"
coreStaticRuntimeKind CoreBoolType = "bool"
coreStaticRuntimeKind (CoreFloatType _) = "float"
coreStaticRuntimeKind CoreTextType = "string"
coreStaticRuntimeKind CoreCharType = "char"
coreStaticRuntimeKind (CoreTupleType _) = "tuple"
coreStaticRuntimeKind (CoreRecordType name _) = displayName name
coreStaticRuntimeKind (CoreArrayType _) = "array"
coreStaticRuntimeKind (CoreMapType _ _) = "map"
coreStaticRuntimeKind (CoreSetType _) = "set"
coreStaticRuntimeKind (CoreStoreType _) = "store"
coreStaticRuntimeKind CoreRangeType = "range"
coreStaticRuntimeKind CoreBytesType = "bytes"
coreStaticRuntimeKind CoreDecimalType = "decimal"
coreStaticRuntimeKind (CoreHandleType _ name) = name
coreStaticRuntimeKind (CoreCallbackType owner _) = owner
coreStaticRuntimeKind (CoreFunctionType _ _) = "function"
coreStaticRuntimeKind kind = coreTypeName kind

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

{-| The trailing parameter of a function with defaults: how many arguments
    its caller wrote. No source identifier can spell it, so a backend finds
    it by name. -}
suppliedCountName :: Text
suppliedCountName = "#supplied"
