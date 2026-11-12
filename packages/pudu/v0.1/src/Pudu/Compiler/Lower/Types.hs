{-| @Pudu.Compiler.Lower.Types — settled checker facts for native representation. -}
module Pudu.Compiler.Lower.Types
  ( LowerTypes, emptyTypes, nativeTypes, withShapes, withBindings, withFacts, typeBindings, lookupScheme, typeForSpan, typeFactAt, sharedReferenceTarget, referenceTarget, loanedInputs
  , dynamicIdentity, isDynamic, unformed, writtenLabel, selectedMember, formedCoreType, formedCoreTypeIn, ownerKeyOf, layoutOf, recordFields, sumVariants, nativeIntegerKind, nativeScalarType, nativeValueType, treeType ) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Core (CoreLayout (..), CoreType (..), CoreVariant (..), coreTypeName)
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (BigIntKind, PlatformSigned, PlatformUnsigned, SignedKind, UnsignedKind), integerKindName, integerKindOf)
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Source (Span)
import Pudu.Type (TypeInfo (..), typeAt)
import Pudu.Type.Value
  ( NominalId (..), Scheme, Type (..), boolType, charType, nominalKey, requiredCount, stringType )

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

{-| An expression typed `&mut T` is a loaned parameter or a lent place, and
    holds a T. -}
typeForSpan :: LowerTypes -> Span -> Maybe CoreType
typeForSpan types@(LowerTypes info _ _ _) at = typeAt info at >>= formedCoreTypeIn types . lentTarget

lentTarget :: Type -> Type
lentTarget (ReferenceTypeValue True target) = target
lentTarget other = other

{-| The positions of a function type's `&mut` inputs. -}
loanedInputs :: Type -> [Int]
loanedInputs value = case value of
  FunctionTypeRequiring _ inputs _ _ -> [index | (index, ReferenceTypeValue True _) <- zip [0 ..] inputs]
  _ -> []

{-| Facts for spans a lowering made up, laid over the checked ones. -}
withFacts :: [(Span, Type)] -> LowerTypes -> LowerTypes
withFacts facts (LowerTypes (TypeInfo offsets entries) schemes shapes bindings) =
  LowerTypes (TypeInfo offsets (Map.union (Map.fromList facts) entries)) schemes shapes bindings

{-| The fact itself, before forming: what a generic call was instantiated at. -}
typeFactAt :: LowerTypes -> Span -> Maybe Type
typeFactAt (LowerTypes info _ _ _) = typeAt info

sharedReferenceTarget :: LowerTypes -> Span -> Maybe CoreType
sharedReferenceTarget types@(LowerTypes info _ _ _) at = case typeAt info at of
  Just (ReferenceTypeValue False target) -> formedCoreTypeIn types target
  _ -> Nothing

{-| What a reference of either kind refers to; a `&mut` parameter holds
    its target's value, so dereferencing it reads that value. -}
referenceTarget :: LowerTypes -> Span -> Maybe CoreType
referenceTarget types@(LowerTypes info _ _ _) at = case typeAt info at of
  Just (ReferenceTypeValue _ target) -> formedCoreTypeIn types target
  _ -> Nothing

{-| The label a checked constructor path names. Checking rewrites a variant
    to a `::constructor::` or `::sum::` path carrying its canonical owner,
    and a record or a constructor pattern to its canonical key; the label is
    what the source wrote last. -}
writtenLabel :: ModuleName -> Text
writtenLabel (ModuleName segments) = case segments of
  "::constructor::" :| [_, label] -> label
  "::sum::" :| (_ : label : _) -> label
  _ -> last (Text.splitOn "." (NonEmpty.last segments))

{-| A member as checking selected it: `::Main.Get::get` names the trait that
    provides `get`, as `Eval.Env.lookupMethod` reads it. A member checking did
    not select is its own name. -}
selectedMember :: Text -> (Maybe Text, Text)
selectedMember written = case Text.splitOn "::" written of
  ["", provider, member] -> (Just provider, member)
  _ -> (Nothing, written)

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
  CoreStoreType _ -> Just "Buckets"
  CoreRangeType -> Just "Range"
  CoreBytesType -> Just "Bytes"
  CoreDecimalType -> Just "Decimal"
  _ -> Nothing

formedWith :: Shapes -> [CoreType] -> Map Text CoreType -> Type -> Maybe CoreType
formedWith shapes seen parameters value = case value of
  ReferenceTypeValue False target -> formedWith shapes seen parameters target
  -- A restriction says what a caller must hold, not how the value is laid out.
  RestrictedType _ inner -> formedWith shapes seen parameters inner
  RigidType name | Just bound <- Map.lookup name parameters -> Just bound
  -- A constructor parameter applied: the constructor it is bound to takes
  -- the arguments it already has, then these.
  AppliedType (RigidType name) arguments
    | Just (key, prefix) <- Map.lookup name parameters >>= constructorOf -> do
        formed <- traverse (formedWith shapes seen parameters) arguments
        formedWith shapes seen parameters (NominalType (keyIdentity key) (map unformed (prefix <> formed)))
  -- A dynamic value holds one of the trait's implementing types.
  DynamicTypeValue identity
    | Map.member (dynamicIdentity identity) (shapeSums shapes) ->
        formedWith shapes seen parameters (NominalType (dynamicIdentity identity) [])
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
  NominalType (NominalId Nothing "Buckets") [held] -> do
    formed <- formedWith shapes seen parameters held
    if nativeValueType formed then Just (CoreStoreType formed) else Nothing
  NominalType (NominalId Nothing "Range") _ -> Just CoreRangeType
  NominalType (NominalId Nothing "Bytes") [] -> Just CoreBytesType
  NominalType (NominalId Nothing "Decimal") [] -> Just CoreDecimalType
  NominalType (NominalId Nothing "Set") [member] -> do
    formed <- formedWith shapes seen parameters member
    if nativeValueType formed then Just (CoreSetType formed) else Nothing
  -- A task is the body it has not run yet: a function of nothing answering
  -- what the body answers, a Result when the task can fail.
  NominalType (NominalId Nothing "Task") [success, failure] -> do
    answered <- case failure of
      NeverType -> formedWith shapes seen parameters success
      _ -> formedWith shapes seen parameters (NominalType (NominalId Nothing "Result") [success, failure])
    if nativeValueType answered then Just (CoreFunctionType [] answered) else Nothing
  -- An async function answers the task of its body, and lends nothing.
  FunctionTypeRequiring True inputs required result
    | all (not . isLoan) inputs -> do
        formedInputs <- traverse (formedWith shapes seen parameters) inputs
        formedResult <- formedWith shapes seen parameters result
        let supplied = [CoreIntegerType PlatformSigned | requiredCount required < length inputs]
        if all nativeValueType (formedResult : formedInputs)
          then Just (CoreFunctionType (formedInputs <> supplied) (CoreFunctionType [] formedResult)) else Nothing
  -- One with defaults takes how many arguments the call supplied as a last
  -- Int, so a value of it and the function it calls agree on arity.
  -- A `&mut T` input takes a T, and a call answers each final beside the
  -- result, as a loaned function's body does.
  FunctionTypeRequiring False inputs required result -> do
    formedInputs <- traverse (formedWith shapes seen parameters . lentTarget) inputs
    formedResult <- formedWith shapes seen parameters result
    let supplied = [CoreIntegerType PlatformSigned | requiredCount required < length inputs]
        finals = [formed | (ReferenceTypeValue True _, formed) <- zip inputs formedInputs]
        answered = if null finals then formedResult else CoreTupleType (formedResult : finals)
    if all nativeValueType formedInputs && (nativeValueType formedResult || formedResult == CoreNeverType)
      then Just (CoreFunctionType (formedInputs <> supplied) answered) else Nothing
  TupleTypeValue members@(_ : _ : _) -> do
    formedMembers <- traverse (formedWith shapes seen parameters) members
    if all nativeValueType formedMembers then Just (CoreTupleType formedMembers) else Nothing
  _ -> builtin value

{-| The sum a trait's dynamic type forms to: the trait's own identity under
    a `dynamic` module no program can declare. -}
dynamicIdentity :: NominalId -> NominalId
dynamicIdentity (NominalId owner name) = NominalId (Just (ModuleName ("dynamic" :| maybe [] (\(ModuleName path) -> NonEmpty.toList path) owner))) name

isDynamic :: CoreType -> Bool
isDynamic kind = case kind of
  CoreSumType key [] -> "dynamic." `Text.isPrefixOf` key
  _ -> False

isLoan :: Type -> Bool
isLoan (ReferenceTypeValue True _) = True
isLoan _ = False

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
nativeIntegerKind BigIntKind = True

nativeScalarType :: CoreType -> Bool
nativeScalarType (CoreIntegerType kind) = nativeIntegerKind kind
nativeScalarType (CoreFloatType _) = True
nativeScalarType CoreBoolType = True
nativeScalarType CoreCharType = True
nativeScalarType CoreUnitType = True
nativeScalarType _ = False

{-| Maps, sets and indexed stores: the values held in a shared tree. -}
treeType :: CoreType -> Bool
treeType kind = case kind of
  CoreMapType _ _ -> True
  CoreSetType _ -> True
  CoreStoreType _ -> True
  _ -> False

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
nativeValueType (CoreStoreType _) = True
nativeValueType CoreRangeType = True
nativeValueType CoreBytesType = True
nativeValueType CoreDecimalType = True
nativeValueType other = nativeScalarType other

{-| The checker's spelling of a formed type: the identity `nominalKey` was
    made from, builtins by their own name. -}
unformed :: CoreType -> Type
unformed kind = case kind of
  CoreRecordType key arguments -> NominalType (identityOf key) (map unformed arguments)
  CoreSumType key arguments -> NominalType (identityOf key) (map unformed arguments)
  CoreFunctionType inputs result -> FunctionTypeValue False (map unformed inputs) (unformed result)
  CoreArrayType member -> NominalType (NominalId Nothing "Array") [unformed member]
  CoreMapType key value -> NominalType (NominalId Nothing "Map") [unformed key, unformed value]
  CoreSetType member -> NominalType (NominalId Nothing "Set") [unformed member]
  CoreStoreType held -> NominalType (NominalId Nothing "Buckets") [unformed held]
  CoreRangeType -> NominalType (NominalId Nothing "Range") [NominalType (NominalId Nothing "Int") []]
  CoreTupleType members -> TupleTypeValue (map unformed members)
  CoreUnitType -> UnitTypeValue
  CoreNeverType -> NeverType
  other -> NominalType (NominalId Nothing (coreTypeName other)) []
 where
  identityOf = keyIdentity

{-| The identity a canonical key was made from. -}
keyIdentity :: Text -> NominalId
keyIdentity key = case NonEmpty.nonEmpty (Text.splitOn "." key) of
  Just segments | length segments > 1 ->
    NominalId (Just (ModuleName (NonEmpty.fromList (NonEmpty.init segments)))) (NonEmpty.last segments)
  _ -> NominalId Nothing key

{-| A constructor a higher-kinded parameter is bound to: its key and the
    arguments it already has. -}
constructorOf :: CoreType -> Maybe (Text, [CoreType])
constructorOf kind = case kind of
  CoreRecordType key prefix -> Just (key, prefix)
  CoreSumType key prefix -> Just (key, prefix)
  _ -> Nothing
