{-| Typed, source-located contracts for the native compiler path. -}
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
  , CoreRangeMethodName (..)
  , CoreBytesMethodName (..)
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

data CoreModule = CoreModule
  { coreModuleName :: !Text
  , coreModuleEntry :: !Text
  , coreModuleFunctions :: ![CoreFunction]
  
  , coreModuleLayouts :: !(Map CoreType CoreLayout)
  
  , coreModuleClosures :: !(Map Text CoreClosureInfo)
  }
  deriving stock (Eq, Show)

-- Builtin identity and hidden environments are separate callable facts.
data CoreClosureInfo = CoreClosureInfo
  { closureCaptures :: ![CoreType]
  , closureDisplayName :: !Text
  , closureSite :: !Text
  , closureIsBuiltin :: !Bool
  , closureHasEnvironment :: !Bool
  }
  deriving stock (Eq, Show)

data CoreFunction = CoreFunction
  { coreFunctionName :: !Text
  , coreFunctionParameters :: ![CoreParameter]
  , coreFunctionResult :: !CoreType
  , coreFunctionBody :: !CoreBlock
  }
  deriving stock (Eq, Show)

data CoreParameter = CoreParameter
  { coreParameterLocal :: !CoreLocal
  , coreParameterSpan :: !Span
  }
  deriving stock (Eq, Show)

data CoreBlock = CoreBlock
  { coreBlockStatements :: ![CoreStatement]
  , coreBlockResult :: !(Maybe CoreExpression)
  }
  deriving stock (Eq, Show)

-- Local IDs keep shadowed bindings distinct.
data CoreLocal = CoreLocal
  { coreLocalId :: !Int
  , coreLocalName :: !Text
  , coreLocalType :: !CoreType
  }
  deriving stock (Eq, Show)

data CoreStatement = CoreStatement
  { coreStatementSpan :: !Span
  , coreStatementShape :: !CoreStatementShape
  }
  deriving stock (Eq, Show)

newtype CoreLoopId = CoreLoopId Int
  deriving stock (Eq, Ord, Show)

data CoreStatementShape
  = CoreDeclare !CoreLocal !CoreExpression
  | CoreAssign !CoreLocal !CoreExpression
  | CoreEvaluate !CoreExpression
  | CoreIf !CoreExpression !CoreBlock !(Maybe CoreExpression)
  | CoreReturn !(Maybe CoreExpression)
  | CoreBreak !CoreLoopId !(Maybe CoreExpression)
  | CoreContinue !CoreLoopId
  deriving stock (Eq, Show)

data CoreExpression = CoreExpression
  { coreExpressionSpan :: !Span
  , coreExpressionType :: !CoreType
  , coreExpressionShape :: !CoreExpressionShape
  }
  deriving stock (Eq, Show)

data CoreExpressionShape
  = CoreIntegerLiteral !IntegerKind !Integer
  
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
  
  | CoreShow !CoreExpression
  
  | CoreTextMethod !CoreTextMethodName !CoreExpression ![CoreExpression]
  
  | CoreCharCode !CoreExpression
  
  | CoreIntegerFits !IntegerKind !CoreExpression
  
  | CoreCharOfCode !CoreExpression
  
  | CoreIntegerConvert !IntegerKind !CoreExpression
  
  | CoreTuple ![CoreExpression]
  
  | CoreTupleIndex !Int !CoreExpression
  
  | CoreRecord ![(Text, CoreExpression)]
  
  | CoreRecordUpdate !CoreExpression ![(Text, CoreExpression)]
  | CoreField !Text !CoreExpression
  
  | CoreConstruct !Text ![(Text, CoreExpression)]
  
  | CoreMatch !CoreExpression ![CoreArm]
  
  | CoreFailText !Text !(Maybe Text) !CoreExpression !(Maybe CoreExpression)
  
  | CoreRuntimeKind !CoreExpression
  | CorePrint !CoreExpression
  
  | CoreOutputError !Bool !Bool !CoreExpression
  | CoreCall !Text ![CoreExpression]
  
  | CoreClosure !Text ![CoreExpression]
  
  | CoreCapture !Int !CoreExpression
  
  | CoreCallValue !CoreExpression ![CoreExpression]
  
  | CoreArray ![CoreExpression]
  
  | CoreArrayMethod !CoreArrayMethodName !CoreExpression ![CoreExpression]
  
  | CoreKeyedMethod !CoreKeyedMethodName !CoreExpression ![CoreExpression]
  
  | CoreComparable !CoreExpression
  
  | CoreRangeValue !(Maybe CoreExpression) !Bool !(Maybe CoreExpression)
  
  | CoreRangeMethod !CoreRangeMethodName !CoreExpression ![CoreExpression]
  
  | CoreBytesMethod !CoreBytesMethodName !CoreExpression ![CoreExpression]
  
  | CoreIndex !CoreExpression !CoreExpression
  
  | CoreTakeLocal !CoreLocal
  
  | CoreOperatorFailure !Text ![CoreExpression]
  | CoreBlockValue !CoreBlock
  | CoreIfValue !CoreExpression !CoreBlock !CoreExpression
  | CoreWhileValue !CoreLoopId !CoreExpression !CoreBlock
  | CoreLoopValue !CoreLoopId !CoreBlock
  deriving stock (Eq, Show)

data CoreTextMethodName
  = TextLength | TextIsEmpty | TextContains | TextStartsWith | TextEndsWith
  | TextIndexOf | TextSpanOf | TextSpanNotOf | TextDrop | TextTake | TextSlice
  | TextRepeat | TextReverse | TextEscapeHtml | TextReplace | TextTrim | TextToUpper
  | TextToLower | TextCharAt | TextSplit | TextLines | TextChars | TextParsesInt
  | TextIntOf | TextParsesFloat | TextFloatOf
  deriving stock (Eq, Show)

data CoreArrayMethodName
  = ArrayLengthOf | ArrayIsEmptyOf | ArrayGetAt | ArrayIndexOfValue
  | ArrayContainsValue | ArrayPushValue | ArrayPopLast | ArrayInsertAt | ArrayRemoveAt
  | ArraySliceOf | ArrayConcatWith | ArrayJoinWith | ArrayReversed
  deriving stock (Eq, Show)

data CoreRangeMethodName
  = RangeLengthOf
  | RangeIsEmptyOf
  | RangeContainsValue
  | RangeHasStart
  | RangeStartOf
  | RangeHasEnd
  | RangeEndOf
  | RangeIsInclusiveOf
  | RangeIsBoundedOf
  | RangeValuesFor !Text
  | RangeIterated
  | RangeReversedOf
  | RangeStepBy
  | RangeSumOf
  deriving stock (Eq, Show)

data CoreBytesMethodName
  = BytesOfArray | BytesFromText | BytesLengthOf | BytesAtIndex | BytesSliceOf
  | BytesTakeOf | BytesDropOf | BytesConcatWith | BytesIndexOfValue
  | BytesContainsValue | BytesStartsWithValue | BytesEndsWithValue | BytesReversed
  | BytesToArrayOf | BytesIsText | BytesAsText
  deriving stock (Eq, Show)

data CoreKeyedMethodName
  = KeyedSize | KeyedIsEmpty | KeyedContains | KeyedLookup | KeyedInsert | KeyedRemove
  | KeyedKeys | KeyedValues | KeyedEntries | KeyedMerge | KeyedUnion | KeyedIntersect
  | KeyedDifference | KeyedFromArray
  deriving stock (Eq, Show)

data CoreBinaryOperator
  = CoreAdd | CoreSubtract | CoreMultiply | CoreDivide | CoreRemainder | CoreBitAnd
  | CoreBitOr | CoreBitXor | CoreShiftLeft | CoreShiftRight | CoreWrapAdd
  | CoreWrapSubtract | CoreWrapMultiply | CoreSaturateAdd | CoreSaturateSubtract
  | CoreSaturateMultiply | CoreLess | CoreLessOrEqual | CoreGreater
  | CoreGreaterOrEqual | CoreEqual | CoreNotEqual | CoreAnd | CoreOr
  deriving stock (Eq, Show)

-- CorePrint is effect-only; source output Results need their own value path.
data CoreType
  = CoreIntegerType !IntegerKind
  | CoreFloatType !FloatWidth
  | CoreBoolType
  | CoreTextType
  | CoreCharType
  | CoreTupleType ![CoreType]
  
  | CoreRecordType !Text ![CoreType]
  
  | CoreSumType !Text ![CoreType]
  
  | CoreArrayType !CoreType
  
  | CoreMapType !CoreType !CoreType
  | CoreSetType !CoreType
  
  | CoreRangeType
  
  | CoreBytesType
  
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
  CoreRangeType -> "Range[Int]"
  CoreBytesType -> "Bytes"
  CoreFunctionType inputs result -> "fn(" <> Text.intercalate ", " (map coreTypeName inputs) <> ") -> " <> coreTypeName result
  CoreUnitType -> "Unit"
  CoreNeverType -> "Never"

displayName :: Text -> Text
displayName key = case Text.splitOn "." key of
  [] -> key
  segments -> last segments

data CoreLayout
  = CoreRecordLayout ![(Text, CoreType)]
  | CoreSumLayout ![CoreVariant]
  
  | CoreClosureLayout ![(Text, CoreClosureInfo)]
  deriving stock (Eq, Show)

data CoreVariant = CoreVariant
  { coreVariantName :: !Text
  , coreVariantFields :: ![(Text, CoreType)]
  , coreVariantRecord :: !Bool
  }
  deriving stock (Eq, Show)

data CoreArm = CoreArm
  { coreArmSpan :: !Span
  , coreArmPattern :: !CorePattern
  , coreArmGuard :: !(Maybe CoreExpression)
  , coreArmBody :: !CoreExpression
  }
  deriving stock (Eq, Show)

data CorePattern
  = CoreWildcardPattern
  | CoreBindPattern !CoreLocal
  | CoreLiteralPattern !CoreExpression
  | CoreRangePattern !CoreExpression !Bool !CoreExpression
  | CoreTuplePattern ![CorePattern]
  | CoreRecordPattern ![CorePattern]
  | CoreVariantPattern !Text ![CorePattern]
  | CoreAlternativePattern ![CorePattern]
  
  | CoreArrayPattern ![CorePattern] !(Maybe (Maybe CoreLocal)) ![CorePattern]
  deriving stock (Eq, Show)
