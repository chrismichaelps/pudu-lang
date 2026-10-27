{-| @Pudu.Compiler.Lower.Types — settled checker facts for native representation. -}
module Pudu.Compiler.Lower.Types
  ( LowerTypes, emptyTypes, nativeTypes, withShapes, withBindings, typeBindings, lookupScheme, typeForSpan, typeFactAt, sharedReferenceTarget
  , formedCoreType, formedCoreTypeIn, ownerKeyOf, layoutOf, recordFields, sumVariants, nativeIntegerKind, nativeScalarType, nativeValueType ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Core (CoreLayout (..), CoreType (..), CoreVariant (..))
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned, PlatformUnsigned, SignedKind, UnsignedKind), integerKindName, integerKindOf)
import Pudu.Source (Span)
import Pudu.Type (TypeInfo (..), typeAt)
import Pudu.Type.Value
  ( NominalId (..), Scheme, Type (..), boolType, charType, nominalKey, stringType )

{-| Facts from one checked module; complete spans retain generated identity.
    The shapes are the records and sums the root module can name, by nominal
    identity, as checking formed them. The bindings say what each rigid type
    parameter stands for in the copy of a body being lowered: `Self` in a
    trait's default member, say. Facts inside such a body name the parameter,
    so every reading goes through them. -}
data LowerTypes = LowerTypes !TypeInfo !(Map Text Scheme) !Shapes !(Map Text CoreType)

data Shapes = Shapes
  { shapeRecords :: !(Map NominalId ([Text], [(Text, Type)]))
  , shapeSums :: !(Map NominalId ([Text], [(Text, [Type], Maybe [Text])]))
  }

nativeTypes :: Maybe TypeInfo -> [(Text, Scheme)] -> Maybe LowerTypes
nativeTypes info schemes = (\types -> LowerTypes types (Map.fromList schemes) noShapes Map.empty) <$> info

{-| No facts at all, for a module the program does not reach. -}
emptyTypes :: LowerTypes
emptyTypes = LowerTypes (TypeInfo Map.empty Map.empty) Map.empty noShapes Map.empty

noShapes :: Shapes
noShapes = Shapes Map.empty Map.empty

withShapes :: Map NominalId ([Text], [(Text, Type)]) -> Map NominalId ([Text], [(Text, [Type], Maybe [Text])]) -> LowerTypes -> LowerTypes
withShapes records sums (LowerTypes info schemes _ bindings) = LowerTypes info schemes (Shapes records sums) bindings

withBindings :: Map Text CoreType -> LowerTypes -> LowerTypes
withBindings bindings (LowerTypes info schemes shapes _) = LowerTypes info schemes shapes bindings

typeBindings :: LowerTypes -> Map Text CoreType
typeBindings (LowerTypes _ _ _ bindings) = bindings

lookupScheme :: LowerTypes -> Text -> Maybe Scheme
lookupScheme (LowerTypes _ schemes _ _) name = Map.lookup name schemes

typeForSpan :: LowerTypes -> Span -> Maybe CoreType
typeForSpan types@(LowerTypes info _ _ _) at = typeAt info at >>= formedCoreTypeIn types

{-| The fact itself, before forming: what a generic call was instantiated at. -}
typeFactAt :: LowerTypes -> Span -> Maybe Type
typeFactAt (LowerTypes info _ _ _) = typeAt info

sharedReferenceTarget :: LowerTypes -> Span -> Maybe CoreType
sharedReferenceTarget types@(LowerTypes info _ _ _) at = case typeAt info at of
  Just (ReferenceTypeValue False target) -> formedCoreTypeIn types target
  _ -> Nothing

{-| Builtins only; no record or sum is known. -}
formedCoreType :: Type -> Maybe CoreType
formedCoreType = formedCoreTypeIn emptyTypes

{-| A record or sum is admitted when every member it can hold has a native
    representation. One met again inside itself is taken as admitted: it is
    held by reference, so the recursion is finite at run time. -}
formedCoreTypeIn :: LowerTypes -> Type -> Maybe CoreType
formedCoreTypeIn (LowerTypes _ _ shapes bindings) = formedWith shapes [] bindings

{-| The name a value's methods are filed under: a record's or sum's canonical
    key, a builtin's own name. Tuples have none, so only `toText` answers them. -}
ownerKeyOf :: CoreType -> Maybe Text
ownerKeyOf kind = case kind of
  CoreRecordType key _ -> Just key
  CoreSumType key _ -> Just key
  CoreIntegerType integerKind -> Just (integerKindName integerKind)
  CoreFloatType Float32Width -> Just "Float32"
  CoreFloatType Float64Width -> Just "Float64"
  CoreBoolType -> Just "Bool"
  CoreTextType -> Just "Str"
  CoreCharType -> Just "Char"
  CoreUnitType -> Just "()"
  CoreArrayType _ -> Just "Array"
  CoreMapType _ _ -> Just "Map"
  CoreSetType _ -> Just "Set"
  CoreRangeType -> Just "Range"
  CoreBytesType -> Just "Bytes"
  _ -> Nothing

formedWith :: Shapes -> [CoreType] -> Map Text CoreType -> Type -> Maybe CoreType
formedWith shapes seen parameters value = case value of
  ReferenceTypeValue False target -> formedWith shapes seen parameters target
  RigidType name | Just bound <- Map.lookup name parameters -> Just bound
  -- A variable checking left open names a type no value in the program has:
  -- the error of an `Ok(1)` that is never `Err`, the member of `setOf([])`,
  -- the argument of a `setOf` that is only compared. Nothing can observe how
  -- it is represented, so it is unit.
  VariableType _ -> Just CoreUnitType
  NominalType identity arguments
    | Just (names, fields) <- Map.lookup identity (shapeRecords shapes)
    , length names == length arguments -> do
        formedArguments <- traverse (formedWith shapes seen parameters) arguments
        let self = CoreRecordType (nominalKey identity) formedArguments
            bound = Map.fromList (zip names formedArguments)
        if self `elem` seen then Just self else do
          members <- traverse (formedWith shapes (self : seen) bound . snd) fields
          if all nativeValueType members then Just self else Nothing
  NominalType identity arguments
    | Just (names, variants) <- Map.lookup identity (shapeSums shapes)
    , length names == length arguments -> do
        formedArguments <- traverse (formedWith shapes seen parameters) arguments
        let self = CoreSumType (nominalKey identity) formedArguments
            bound = Map.fromList (zip names formedArguments)
        if self `elem` seen then Just self else do
          payloads <- traverse (\(_, payload, _) -> traverse (formedWith shapes (self : seen) bound) payload) variants
          if all (all nativeValueType) payloads then Just self else Nothing
  NominalType (NominalId Nothing "Array") [element] -> do
    formed <- formedWith shapes seen parameters element
    if nativeValueType formed then Just (CoreArrayType formed) else Nothing
  NominalType (NominalId Nothing "Map") [key, held] -> do
    formedKey <- formedWith shapes seen parameters key
    formedValue <- formedWith shapes seen parameters held
    if all nativeValueType [formedKey, formedValue] then Just (CoreMapType formedKey formedValue) else Nothing
  NominalType (NominalId Nothing "Range") _ -> Just CoreRangeType
  NominalType (NominalId Nothing "Bytes") [] -> Just CoreBytesType
  NominalType (NominalId Nothing "Set") [member] -> do
    formed <- formedWith shapes seen parameters member
    if nativeValueType formed then Just (CoreSetType formed) else Nothing
  -- An async function is a task-maker, which native code has no form for.
  FunctionTypeRequiring False inputs _ result -> do
    formedInputs <- traverse (formedWith shapes seen parameters) inputs
    formedResult <- formedWith shapes seen parameters result
    if all nativeValueType formedInputs && (nativeValueType formedResult || formedResult == CoreNeverType)
      then Just (CoreFunctionType formedInputs formedResult) else Nothing
  TupleTypeValue members@(_ : _ : _) -> do
    formedMembers <- traverse (formedWith shapes seen parameters) members
    if all nativeValueType formedMembers then Just (CoreTupleType formedMembers) else Nothing
  _ -> builtin value

recordFields :: LowerTypes -> CoreType -> Maybe [(Text, CoreType)]
recordFields types kind = case layoutOf types kind of
  Just (CoreRecordLayout fields) -> Just fields
  _ -> Nothing

sumVariants :: LowerTypes -> CoreType -> Maybe [CoreVariant]
sumVariants types kind = case layoutOf types kind of
  Just (CoreSumLayout variants) -> Just variants
  _ -> Nothing

{-| How a record or sum named in Core is laid out. -}
layoutOf :: LowerTypes -> CoreType -> Maybe CoreLayout
layoutOf (LowerTypes _ _ shapes _) kind = case kind of
  CoreRecordType name arguments -> do
    (names, fields) <- named name (shapeRecords shapes)
    let bound = Map.fromList (zip names arguments)
    CoreRecordLayout <$> traverse (\(field, fieldType) -> (,) field <$> form bound fieldType) fields
  CoreSumType name arguments -> do
    (names, variants) <- named name (shapeSums shapes)
    let bound = Map.fromList (zip names arguments)
    CoreSumLayout <$> traverse (variant bound) variants
  _ -> Nothing
 where
  form = formedWith shapes [] 
  variant bound (name, payload, fields) = do
    members <- traverse (form bound) payload
    let labels = maybe (map (Text.pack . show) [0 .. length members - 1]) id fields
    Just (CoreVariant name (zip labels members) (fields /= Nothing))
  -- Core names a record or sum by its canonical key, so two modules' types of
  -- one spelling stay apart.
  named key table = case [entry | (identity, entry) <- Map.toList table, nominalKey identity == key] of
    entry : _ -> Just entry
    [] -> Nothing

builtin :: Type -> Maybe CoreType
builtin value
  | NominalType (NominalId Nothing name) [] <- value
  , Just kind <- integerKindOf name
  , nativeIntegerKind kind = Just (CoreIntegerType kind)
  | NominalType (NominalId Nothing "Float64") [] <- value = Just (CoreFloatType Float64Width)
  | NominalType (NominalId Nothing "Float32") [] <- value = Just (CoreFloatType Float32Width)
  | value == boolType = Just CoreBoolType
  | value == stringType = Just CoreTextType
  | value == charType = Just CoreCharType
  | otherwise = case value of
      UnitTypeValue -> Just CoreUnitType
      NeverType -> Just CoreNeverType
      _ -> Nothing

nativeIntegerKind :: IntegerKind -> Bool
nativeIntegerKind PlatformSigned = True
nativeIntegerKind PlatformUnsigned = True
nativeIntegerKind (SignedKind width) = width `elem` [8, 16, 32, 64, 128]
nativeIntegerKind (UnsignedKind width) = width `elem` [8, 16, 32, 64, 128]
nativeIntegerKind _ = False

nativeScalarType :: CoreType -> Bool
nativeScalarType (CoreIntegerType kind) = nativeIntegerKind kind
nativeScalarType (CoreFloatType _) = True
nativeScalarType CoreBoolType = True
nativeScalarType CoreCharType = True
nativeScalarType CoreUnitType = True
nativeScalarType _ = False

{-| What a native slot can hold: the scalars plus owned text and tuples. -}
nativeValueType :: CoreType -> Bool
nativeValueType CoreTextType = True
nativeValueType (CoreTupleType members) = length members >= 2 && all nativeValueType members
nativeValueType (CoreRecordType _ _) = True
nativeValueType (CoreSumType _ _) = True
nativeValueType (CoreFunctionType _ _) = True
nativeValueType (CoreArrayType _) = True
nativeValueType (CoreMapType _ _) = True
nativeValueType (CoreSetType _) = True
nativeValueType CoreRangeType = True
nativeValueType CoreBytesType = True
nativeValueType other = nativeScalarType other
