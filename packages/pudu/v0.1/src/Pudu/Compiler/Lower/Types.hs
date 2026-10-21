{-| @Pudu.Compiler.Lower.Types — settled checker facts for native representation. -}
module Pudu.Compiler.Lower.Types
  ( LowerTypes, nativeTypes, withShapes, lookupScheme, typeForSpan, formedCoreType, formedCoreTypeIn
  , layoutOf, recordFields, sumVariants, nativeIntegerKind, nativeScalarType, nativeValueType ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Core (CoreLayout (..), CoreType (..), CoreVariant (..))
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned, PlatformUnsigned, SignedKind, UnsignedKind), integerKindOf)
import Pudu.Source (Span)
import Pudu.Type (TypeInfo (..), typeAt)
import Pudu.Type.Value
  ( NominalId (..), Scheme, Type (..), boolType, charType, stringType )

{-| Facts from one checked module; complete spans retain generated identity.
    The shapes are the records and sums the root module can name, by nominal
    identity, as checking formed them. -}
data LowerTypes = LowerTypes !TypeInfo !(Map Text Scheme) !Shapes

data Shapes = Shapes
  { shapeRecords :: !(Map NominalId ([Text], [(Text, Type)]))
  , shapeSums :: !(Map NominalId ([Text], [(Text, [Type], Maybe [Text])]))
  }

nativeTypes :: Maybe TypeInfo -> [(Text, Scheme)] -> Maybe LowerTypes
nativeTypes info schemes = (\types -> LowerTypes types (Map.fromList schemes) noShapes) <$> info

noShapes :: Shapes
noShapes = Shapes Map.empty Map.empty

withShapes :: Map NominalId ([Text], [(Text, Type)]) -> Map NominalId ([Text], [(Text, [Type], Maybe [Text])]) -> LowerTypes -> LowerTypes
withShapes records sums (LowerTypes info schemes _) = LowerTypes info schemes (Shapes records sums)

lookupScheme :: LowerTypes -> Text -> Maybe Scheme
lookupScheme (LowerTypes _ schemes _) name = Map.lookup name schemes

typeForSpan :: LowerTypes -> Span -> Maybe CoreType
typeForSpan types@(LowerTypes info _ _) at = typeAt info at >>= formedCoreTypeIn types

{-| Builtins only; no record or sum is known. -}
formedCoreType :: Type -> Maybe CoreType
formedCoreType = formedCoreTypeIn (LowerTypes (TypeInfo Map.empty Map.empty) Map.empty noShapes)

{-| A record or sum is admitted when every member it can hold has a native
    representation. One met again inside itself is taken as admitted: it is
    held by reference, so the recursion is finite at run time. -}
formedCoreTypeIn :: LowerTypes -> Type -> Maybe CoreType
formedCoreTypeIn (LowerTypes _ _ shapes) = formedWith shapes [] Map.empty

formedWith :: Shapes -> [CoreType] -> Map Text CoreType -> Type -> Maybe CoreType
formedWith shapes seen parameters value = case value of
  RigidType name | Just bound <- Map.lookup name parameters -> Just bound
  NominalType identity []
    | Just ([], fields) <- Map.lookup identity (shapeRecords shapes) ->
        let self = CoreRecordType (nominalName identity)
         in if self `elem` seen then Just self else do
              members <- traverse (formedWith shapes (self : seen) Map.empty . snd) fields
              if all nativeValueType members then Just self else Nothing
  NominalType identity arguments
    | Just (names, variants) <- Map.lookup identity (shapeSums shapes)
    , length names == length arguments -> do
        formedArguments <- traverse argument arguments
        let self = CoreSumType (nominalName identity) formedArguments
            bound = Map.fromList (zip names formedArguments)
        if self `elem` seen then Just self else do
          payloads <- traverse (\(_, payload, _) -> traverse (formedWith shapes (self : seen) bound) payload) variants
          if all (all nativeValueType) payloads then Just self else Nothing
   where
    -- A type argument checking left unconstrained names a payload no value in
    -- the program holds, such as the error of `Ok(1)` that is never `Err`, so
    -- any representation of it is unobservable.
    argument held = case held of
      VariableType _ -> Just CoreUnitType
      _ -> formedWith shapes seen parameters held
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
layoutOf (LowerTypes _ _ shapes) kind = case kind of
  CoreRecordType name -> do
    (_, fields) <- named name (shapeRecords shapes)
    CoreRecordLayout <$> traverse (\(field, fieldType) -> (,) field <$> form Map.empty fieldType) fields
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
  -- The root module's own declaration wins over a builtin of the same name.
  named name table = case [entry | (identity, entry) <- Map.toList table, nominalName identity == name, nominalModule identity /= Nothing] of
    entry : _ -> Just entry
    [] -> case [entry | (identity, entry) <- Map.toList table, nominalName identity == name] of
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
nativeValueType (CoreRecordType _) = True
nativeValueType (CoreSumType _ _) = True
nativeValueType other = nativeScalarType other
