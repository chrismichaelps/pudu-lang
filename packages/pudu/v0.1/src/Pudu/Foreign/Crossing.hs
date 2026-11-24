{-| @Program.Foreign.Crossing — what may pass between this language and another

    The set is stated rather than inferred. A general marshaller for arbitrary
    types is how an interface stops being able to say what it does, and every
    value it fails on fails when it is called rather than where it is written.
    [[ADR-0018 Calling a Library Written Elsewhere]] settles the list. -}
module Pudu.Foreign.Crossing
  ( Crossing (..)
  , ObjectiveCMethod (..)
  , objectiveCMethod
  , objectiveCInitializer
  , objectiveCRetainedFamily
  , crossingFor
  , parameterCrossingFor
  , ReturnedRun (..)
  , returnedRunElementFor
  , resolveReturnedRun
  , foreignBounds
  , loanFor
  , runElementFor
  , runLoanFor
  , isArrayCrossingSyntax
  , isOptionCrossingSyntax
  , optionalHandleFor
  , isAbsentLoanArgument
  , isLoanPointee
  , crossingName
  , crossingType
  , crossableNames
  , RecordLayouts
  , recordLayouts
  , fitsCrossing
  , foreignArgumentLimit
  , foreignRecordFieldLimit
  ) where

import Data.Data (Data)
import Control.Monad (unless)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Foreign.Extent (ForeignBound (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import qualified Data.Map.Strict as Map
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Expression (..)
  , FieldDeclaration (..)
  , ForeignLength (..)
  , ForeignFunction (..)
  , ForeignClass (..)
  , ForeignMethod (..)
  , ForeignParameter (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , TypeSyntax (..)
  )
import Data.Char (isAsciiLower)
import Data.List (find)
import Data.String (fromString)
import Pudu.Type.Value (Type (..))
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NonEmpty
import Pudu.Source (Span)

data ObjectiveCMethod = ObjectiveCMethod
  { objectiveCSelector :: !Text
  , objectiveCClass :: !(Maybe Text)
  }
  deriving stock (Data, Eq, Ord, Show)

objectiveCInitializer :: ObjectiveCMethod -> Bool
objectiveCInitializer = selectorFamily "init" . objectiveCSelector

objectiveCRetainedFamily :: Text -> Bool
objectiveCRetainedFamily selector =
  any (`selectorFamily` selector) ["alloc", "new", "copy", "mutableCopy", "init"]

selectorFamily :: Text -> Text -> Bool
selectorFamily name selector =
  case Text.stripPrefix name (Text.takeWhile (/= ':') (Text.dropWhile (== '_') selector)) of
    Just remainder -> maybe True (not . isAsciiLower . fst) (Text.uncons remainder)
    Nothing -> False

objectiveCMethod :: [ForeignClass] -> ForeignFunction -> Maybe ObjectiveCMethod
objectiveCMethod classes function = do
  method <- foreignMethod function
  receiver <- traverse resolvedClass (foreignMethodClass method)
  pure (ObjectiveCMethod (locatedValue (foreignMethodSelector method)) receiver)
 where
  resolvedClass name = locatedValue . foreignClassSymbol <$>
    find ((== locatedValue name) . locatedValue . foreignClassName) classes

{-| One value's representation on the other side.

    A width is part of the declaration rather than part of the program's type,
    which is the whole trick: `Int32` says how many bits leave, and what stays
    here is the language's own integer. A binding that spread machine widths
    through the code that calls it is how a foreign library's shape ends up
    dictating the shape of everything that touches it. -}
data Crossing
  = SignedCrossing !Int
  | UnsignedCrossing !Int
  | FloatingCrossing !Int
  | BooleanCrossing
  | TextCrossing
  {-| A run of bytes the library reads, and only reads.

      Pudu's own storage, handed over as an address for the length of the call
      and no longer. The length travels as an ordinary argument because in C it
      is one: a run of bytes carries no terminator, so the library is told how
      far to read the way its other callers tell it. -}
  | BytesCrossing
  {-| An address the library hands back, under the name its own block gave it.

      Opaque: nothing here reads through it, and the name is carried so a
      texture cannot be passed where a window is wanted. A library's handles are
      not interchangeable, and one address type for all of them turns a mistake
      the checker could catch into one the library reports by failing. -}
  | HandleCrossing !Text
  {-| A handle a parameter may leave out: `Option` of a type the block
      declares. `None` crosses as the null address a library reads as
      "none given", and `Some` as the handle it holds, which must be live. -}
  | OptionalHandleCrossing !Text
  {-| A record crossing by value, under its name and with its fields in the
      order the declaration wrote them.

      Where a field sits inside the record is the platform's answer rather than
      this one's, so only the names and widths are carried here; the boundary
      asks for the offsets when it lays the bytes out. -}
  | RecordCrossing !Text ![(Text, Crossing)]
  | NothingCrossing
  deriving stock (Eq, Show)

{-| The records a module declares, by name, with their fields in order.

    Built from the same declarations the checker and the evaluator each already
    walk, so both see one layout and neither has to be told about the other. -}
type RecordLayouts = Map.Map Text [(Text, Located TypeSyntax)]

{-| The fixed native call-frame capacity, exposed to declaration checking. -}
foreignArgumentLimit :: Int
foreignArgumentLimit = 32

{-| The fixed flat-record description capacity, exposed to declaration checking. -}
foreignRecordFieldLimit :: Int
foreignRecordFieldLimit = 32

recordLayouts :: [Located Declaration] -> RecordLayouts
recordLayouts declarations =
  Map.fromList
    [ (locatedValue (typeName value), fields)
    | Located _ (TypeDeclaration value) <- declarations
    , RecordDefinition declared <- [locatedValue (typeDefinition value)]
    , let fields =
            [ (locatedValue (fieldName field), fieldType field)
            | Located _ field <- declared
            ]
    ]

{-| The crossing a declared type describes, where it describes one.

    Anything absent from this is refused at the declaration, which is the point
    of stating it: a type that cannot cross is a diagnostic where it is written
    rather than a fault where it is called. -}
crossingFor :: Set Text -> RecordLayouts -> Located TypeSyntax -> Maybe Crossing
crossingFor handles layouts = crossingAt Set.empty
 where
  crossingAt enclosing (Located _ syntax) = case syntax of
    UnitType -> Just NothingCrossing
    NamedType (ModuleName (name :| [])) [] -> named enclosing name
    _ -> Nothing

  {-| A record's fields are themselves crossable, and may themselves be records.

      A camera holds two points, a font holds a texture, and a record that
      admitted only numbers would admit almost nothing a library actually
      passes. The record shape retains its
      nesting so the bridge can preserve the platform ABI's padding.

      A record reached from inside itself has no finite layout. The set of
      records already open refuses it where it is
      written rather than looping. -}
  named enclosing name
    | Set.member name handles = Just (HandleCrossing name)
    | Set.member name enclosing = Nothing
    | Just fields <- Map.lookup name layouts =
        if null fields || length fields > foreignRecordFieldLimit
          then Nothing
          else RecordCrossing name <$> traverse (field (Set.insert name enclosing)) fields
    | otherwise = scalar name
   where
    field inner (label, written) = do
      crossing <- crossingAt inner written
      case crossing of
        NothingCrossing -> Nothing
        HandleCrossing _ -> Nothing
        {-| A record crosses as the leaves it flattens to, and a run of bytes is
            not a leaf: it is an address and a length that no field names. -}
        BytesCrossing -> Nothing
        _ -> Just (label, crossing)

  scalar name = case name of
    "Int8" -> Just (SignedCrossing 8)
    "Int16" -> Just (SignedCrossing 16)
    "Int32" -> Just (SignedCrossing 32)
    "Int64" -> Just (SignedCrossing 64)
    "UInt8" -> Just (UnsignedCrossing 8)
    "UInt16" -> Just (UnsignedCrossing 16)
    "UInt32" -> Just (UnsignedCrossing 32)
    "UInt64" -> Just (UnsignedCrossing 64)
    "Float32" -> Just (FloatingCrossing 32)
    "Float64" -> Just (FloatingCrossing 64)
    "Bool" -> Just BooleanCrossing
    "Str" -> Just TextCrossing
    "Bytes" -> Just BytesCrossing
    _ -> Nothing

{-| The crossing a declared parameter describes: any crossing a value has,
    and also `Option` of a handle the block declares, which only an argument
    may be. A result or a field that can be absent answers through a slot. -}
parameterCrossingFor :: Set Text -> RecordLayouts -> Located TypeSyntax -> Maybe Crossing
parameterCrossingFor handles layouts written = case optionalHandleFor handles written of
  Just (HandleCrossing name) -> Just (OptionalHandleCrossing name)
  _ -> crossingFor handles layouts written
{-| The mutability and pointee of a reference admitted as a foreign input. -}
loanFor :: Set Text -> RecordLayouts -> Located TypeSyntax -> Maybe (Bool, Crossing)
loanFor handles layouts (Located _ syntax) = case syntax of
  ReferenceType exclusive written -> do
    pointee <- crossingFor handles layouts written
    if isLoanPointee pointee then Just (exclusive, pointee) else Nothing
  _ -> Nothing

{-| A foreign run uses the dynamic array spelling and a scalar-only ABI element. -}
runElementFor :: Set Text -> RecordLayouts -> Located TypeSyntax -> Maybe Crossing
runElementFor handles layouts (Located _ syntax) = case syntax of
  NamedType (ModuleName ("Array" :| [])) [written] -> do
    element <- crossingFor handles layouts written
    if isLoanPointee element then Just element else Nothing
  _ -> Nothing

runLoanFor :: Set Text -> RecordLayouts -> Located TypeSyntax -> Maybe (Bool, Crossing)
runLoanFor handles layouts (Located _ syntax) = case syntax of
  ReferenceType mutable pointee -> (,) mutable <$> runElementFor handles layouts pointee
  _ -> Nothing

isArrayCrossingSyntax :: Located TypeSyntax -> Bool
isArrayCrossingSyntax (Located _ syntax) = case syntax of
  NamedType (ModuleName ("Array" :| [])) [_] -> True
  _ -> False

isOptionCrossingSyntax :: Located TypeSyntax -> Bool
isOptionCrossingSyntax (Located _ syntax) = case syntax of
  NamedType (ModuleName ("Option" :| [])) _ -> True
  _ -> False

{-| The checked native result is a pointer. The length ordinal identifies
    a member of the compact output-slot sequence after the native result. -}
data ReturnedRun = ReturnedRun
  { returnedRunElement :: !Crossing
  , returnedRunOptional :: !Bool
  , returnedRunLengthSlot :: !Int
  , returnedRunHandle :: !Text
  }
  deriving stock (Eq, Show)

returnedRunElementFor :: Set Text -> RecordLayouts -> Located TypeSyntax -> Maybe (Bool, Crossing)
returnedRunElementFor handles layouts written@(Located _ syntax) = case syntax of
  NamedType (ModuleName ("Option" :| [])) [array] -> (,) True <$> runElementFor handles layouts array
  _ -> (,) False <$> runElementFor handles layouts written

resolveReturnedRun
  :: Set Text -> RecordLayouts -> Map.Map Text ForeignFunction -> ForeignFunction
  -> Either (Span, Text) (Maybe ReturnedRun)
resolveReturnedRun handles layouts functions producer =
  traverse resolve (foreignResultLength producer)
 where
  result = foreignResult producer
  resolve lengthName = do
    (optional, element) <- require result "a returned run needs a fixed-width scalar or record element"
      (returnedRunElementFor handles layouts result)
    slotIndex <- lengthPosition lengthName
    unless (not (foreignResultBorrowed producer) && not (foreignResultCounted producer)) $
      Left (locatedSpan result, "a returned run must transfer one owned allocation")
    releaseName <- require result "a returned run must name the release for its allocation"
      (foreignReleasedBy producer)
    release <- require releaseName "this block declares no release with that name"
      (Map.lookup (locatedValue releaseName) functions)
    handle <- releaseHandleName releaseName release
    case crossingFor handles layouts (foreignResult release) of
      Just kind | kind == NothingCrossing || isIntegralCrossing kind -> Right ()
      _ -> Left (locatedSpan releaseName, "a run release must return unit or a fixed-width integer")
    pure ReturnedRun
      { returnedRunElement = element
      , returnedRunOptional = optional
      , returnedRunLengthSlot = slotIndex
      , returnedRunHandle = handle
      }
  lengthPosition named = case matching named of
    [(slotIndex, parameter)]
      | Just written <- foreignParameterType parameter
      , Just kind <- crossingFor handles layouts written
      , isIntegralCrossing kind
      , not (foreignParameterOwned parameter) -> Right slotIndex
    _ -> Left (locatedSpan named, "a returned run length must name one fixed-width integer output slot")
  matching named =
    [ (slotIndex, parameter)
    | (slotIndex, parameter) <- zip [0 ..] outputSlots
    , locatedValue (foreignParameterName parameter) == locatedValue named ]
  outputSlots =
    [parameter | Located _ parameter <- foreignParameters producer, foreignParameterOut parameter]
  releaseHandleName named release = case foreignParameters release of
    [Located _ parameter]
      | not (foreignParameterOut parameter || foreignParameterContext parameter || foreignParameterOwned parameter)
      , foreignParameterNullable parameter == Nothing
      , foreignReleasedBy release == Nothing
      , not (foreignResultBorrowed release || foreignResultCounted release)
      , Just written <- foreignParameterType parameter
      , Just (HandleCrossing handle) <- crossingFor handles layouts written -> Right handle
    _ -> Left (locatedSpan named, "a run release must take exactly one declared opaque handle")
  require at message = maybe (Left (locatedSpan at, message)) Right

isIntegralCrossing :: Crossing -> Bool
isIntegralCrossing crossing = case crossing of
  SignedCrossing _ -> True
  UnsignedCrossing _ -> True
  _ -> False

{-| Optionality belongs to the language value. Both cases cross as one pointer. -}
optionalHandleFor :: Set Text -> Located TypeSyntax -> Maybe Crossing
optionalHandleFor handles (Located _ syntax) = case syntax of
  NamedType (ModuleName ("Option" :| []))
    [Located _ (NamedType (ModuleName (name :| [])) [])]
      | Set.member name handles -> Just (HandleCrossing name)
  _ -> Nothing

isAbsentLoanArgument :: Located Expression -> Bool
isAbsentLoanArgument (Located _ syntax) = case syntax of
  NameExpression ("None" :| []) -> True
  RecordExpression (ModuleName ("::constructor::" :| ["Option", "None"])) [] -> True
  _ -> False

{-| Resolve signature-local names before either execution path sees a bound. -}
foreignBounds
  :: Set Text -> RecordLayouts -> [Located ForeignParameter]
  -> Either (Span, Text) [ForeignBound]
foreignBounds handles layouts parameters =
  traverse resolve
    [(index, parameter, relation) | (index, parameter) <- positions
                                  , Just relation <- [foreignParameterLength parameter]]
 where
  positions = zip [0 ..] (map locatedValue parameters)
  input parameter =
    not (foreignParameterContext parameter || foreignParameterOut parameter)
  resolve (index, parameter, ForeignLength unit targets)
    | input parameter
    , foreignParameterNullable parameter == Nothing
    , Just crossing <- foreignParameterType parameter >>= crossingFor handles layouts
    , isIntegralCrossing crossing = do
        resolved <- traverse resolveTarget targets
        let repeated = duplicate Set.empty (NonEmpty.toList targets)
        case repeated of
          Just name -> Left (locatedSpan name, "a foreign length names the same run more than once")
          Nothing -> Right (ForeignBound index (locatedValue unit) resolved)
    | otherwise = Left (locatedSpan unit, "a foreign length must be a fixed-width integer input")
  resolveTarget target =
    case [(index, parameter) | (index, parameter) <- positions
                            , locatedValue (foreignParameterName parameter) == locatedValue target] of
      [(index, parameter)]
        | input parameter
        , Just written <- foreignParameterType parameter
        , isRun written -> Right index
      _ -> Left (locatedSpan target, "this foreign length target must name an input buffer")
  isRun written@(Located _ syntax) =
    crossingFor handles layouts written == Just BytesCrossing || case syntax of
      ReferenceType _ pointee -> runElementFor handles layouts pointee /= Nothing
      _ -> False
  duplicate _ [] = Nothing
  duplicate seen (name : rest)
    | Set.member (locatedValue name) seen = Just name
    | otherwise = duplicate (Set.insert (locatedValue name) seen) rest

{-| A copied loan carries a finite layout with no pointer-bearing leaves. -}
isLoanPointee :: Crossing -> Bool
isLoanPointee = \case
  SignedCrossing _ -> True
  UnsignedCrossing _ -> True
  FloatingCrossing _ -> True
  BooleanCrossing -> True
  RecordCrossing _ fields -> all (isLoanPointee . snd) fields
  TextCrossing -> False
  BytesCrossing -> False
  HandleCrossing _ -> False
  OptionalHandleCrossing _ -> False
  NothingCrossing -> False

{-| What the declaration wrote, for a diagnostic to name back. -}
crossingName :: Crossing -> Text
crossingName crossing = case crossing of
  SignedCrossing width -> "Int" <> Text.pack (show width)
  UnsignedCrossing width -> "UInt" <> Text.pack (show width)
  FloatingCrossing width -> "Float" <> Text.pack (show width)
  BooleanCrossing -> "Bool"
  TextCrossing -> "Str"
  BytesCrossing -> "Bytes"
  HandleCrossing name -> name
  OptionalHandleCrossing name -> "Option[" <> name <> "]"
  RecordCrossing name _ -> name
  NothingCrossing -> "()"

{-| The type a crossed value has on this side.

    The same type the declaration wrote. This language already carries widths —
    `Int32` is one of its own types, not a spelling invented for the boundary —
    so a foreign signature is an ordinary signature, and a caller passing the
    wrong width is told so by the ordinary checker rather than by a second one
    that only exists here. -}
crossingType :: Crossing -> Type
crossingType crossing = case crossing of
  NothingCrossing -> UnitTypeValue
  OptionalHandleCrossing name -> NominalType "Option" [NominalType (fromString (Text.unpack name)) []]
  _ -> NominalType (fromString (Text.unpack (crossingName crossing))) []

{-| Whether an integer is one the declared width can carry.

    Checked at the boundary rather than wrapped there. Silent wraparound is the
    original sin of calling C from anywhere: a value that does not fit becomes a
    different value, and the program continues with it. -}
fitsCrossing :: Crossing -> Integer -> Bool
fitsCrossing crossing value = case crossing of
  SignedCrossing width -> value >= negate (2 ^ (width - 1)) && value < 2 ^ (width - 1)
  UnsignedCrossing width -> value >= 0 && value < 2 ^ width
  _ -> True

{-| The names a declaration may write, for a diagnostic to offer. -}
crossableNames :: Text
crossableNames =
  "Int8 Int16 Int32 Int64, UInt8 UInt16 UInt32 UInt64, Float32 Float64, Bool, Str, Bytes, (), "
    <> "and a type the block itself declares"
