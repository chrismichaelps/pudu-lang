{-| @Pudu.Compiler.Lower.Dynamic — `dynamic Trait` as a sum over the trait's
    implementing types, one variant each holding the value; a concrete value
    widens into its variant where a dynamic one is expected, and a method
    call selects the held type's implementation. -}
module Pudu.Compiler.Lower.Dynamic
  ( dynamicSums, isDynamic, widen, widenBlock, widenTo, writtenType, pathText
  , joinRuntimeArms, mapRuntimeChoice, runtimeCarriers, runtimeResultType
  , preserveRuntimeResult, projectRuntimeValue, hasRuntimeChoice
  , missingRuntimeMember, invalidRuntimeIndex
  , storageCarrier, settledMutableLayout, commonAggregateCarrier, recordWithFields, sumWithPayload, normalizeAggregateValue ) where

import Data.List (find, mapAccumL, transpose)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), MutableSite, bindLocal, intType, refused)
import Pudu.Compiler.Lower.Types (LowerTypes, dynamicIdentity, isDynamic, recordFields, sumVariants)
import Pudu.Core
import Pudu.Frontend.Syntax
  ( Declaration (..), Impl (..), Located (..), Module (..), Trait (..), TypeSyntax (..), moduleNameText )
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned))
import Pudu.Source (Span)
import Pudu.Type.Value (NominalId (..), Type (..), nominalKey)

{-| Ground payloads supplied by checked widenings join the implementation
    heads that already name one concrete type. -}
dynamicSums :: [Module] -> [(Span, NominalId, Type)] -> Map NominalId ([Text], [(Text, [Type], Maybe [Text])])
dynamicSums modules widenings = Map.map (\variants -> ([], dedupe variants)) $ Map.fromListWith (flip (<>)) $
  [ (dynamicIdentity (identityOf (moduleNameText (locatedValue (moduleName syntax)) <> "." <> locatedValue (traitName trait))), [])
  | syntax <- modules
  , Located _ (TraitDeclaration trait) <- moduleDeclarations syntax ]
  <> [ entry (identityOf (qualified syntax trait)) owner held
     | syntax <- modules
     , Located _ (ImplDeclaration impl) <- moduleDeclarations syntax
     , null (implTypeParams impl)
     , NamedType trait _ <- [locatedValue (implTrait impl)]
     , Just held@(NominalType owner _) <- [writtenType [] (implTarget impl)] ]
  <> [ entry trait owner held
     | (_, trait, held@(NominalType owner _)) <- widenings
     , concrete held ]
 where
  entry trait owner held = (dynamicIdentity trait, [(tag owner held, [held], Nothing)])
  tag owner (NominalType _ arguments@(_ : _)) = nominalKey owner <> "#" <> Text.pack (show arguments)
  tag owner _ = nominalKey owner
  qualified syntax trait
    | Text.isInfixOf "." (pathText trait) = pathText trait
    | otherwise = moduleNameText (locatedValue (moduleName syntax)) <> "." <> pathText trait
  dedupe = keep Set.empty
  keep _ [] = []
  keep seen (variant@(name, _, _) : rest)
    | Set.member name seen = keep seen rest
    | otherwise = variant : keep (Set.insert name seen) rest

concrete :: Type -> Bool
concrete kind = case kind of
  NominalType _ arguments -> all concrete arguments
  TupleTypeValue members -> all concrete members
  FunctionTypeRequiring _ inputs _ result -> all concrete (result : inputs)
  ReferenceTypeValue _ target -> concrete target
  RestrictedType _ target -> concrete target
  DynamicTypeValue _ -> True
  UnitTypeValue -> True
  NeverType -> True
  _ -> False

{-| A written type as checking forms it, with these names rigid. Resolution
    has already made every path canonical. -}
writtenType :: [Text] -> Located TypeSyntax -> Maybe Type
writtenType rigid (Located _ written) = case written of
  NamedType path arguments -> do
    formed <- traverse (writtenType rigid) arguments
    let name = pathText path
    pure $ if name `elem` rigid && null arguments then RigidType name
      else if name == "Never" then NeverType else NominalType (identityOf name) formed
  DynamicType path -> Just (DynamicTypeValue (identityOf (pathText path)))
  TupleType members -> TupleTypeValue <$> traverse (writtenType rigid) members
  ReferenceType mutable held -> ReferenceTypeValue mutable <$> writtenType rigid held
  FunctionType asynchronous inputs result -> FunctionTypeValue asynchronous
    <$> traverse (writtenType rigid) inputs <*> writtenType rigid result
  UnitType -> Just UnitTypeValue
  _ -> Nothing

identityOf :: Text -> NominalId
identityOf name = case reverse (Text.splitOn "." name) of
  member : owners -> NominalId (ModuleName <$> NonEmpty.nonEmpty (reverse owners)) member
  [] -> NominalId Nothing name

pathText :: ModuleName -> Text
pathText (ModuleName path) = Text.intercalate "." (NonEmpty.toList path)

{-| The value as the expected type holds it: itself when it already is one,
    its variant when the expected type is dynamic and the value's type
    implements the trait. A literal whose members are expected dynamic is
    built again with each member widened, to any depth. -}
widen :: LowerTypes -> CoreType -> CoreExpression -> CoreExpression
widen types expected core
  | actual == expected || actual == CoreNeverType = core
  | Just alternatives <- runtimeChoiceAlternatives expected
  , Just (tag, _) <- find ((== actual) . snd) alternatives =
      runtimeBox expected tag core
  | isDynamic expected =
      case sumVariants types expected >>= find ((== [actual]) . map snd . coreVariantFields) of
        Just variant -> CoreExpression at expected (CoreConstruct (coreVariantName variant) [("0", core)])
        Nothing -> core
  | otherwise = maybe core (CoreExpression at expected) rebuilt
 where
  actual = coreExpressionType core
  at = coreExpressionSpan core
  settled member kind = coreExpressionType member `elem` [kind, CoreNeverType]
  members kinds given = do
    let widened = zipWith (widen types) kinds given
    if length kinds == length given && and (zipWith settled widened kinds) then Just widened else Nothing
  labelled declared given = do
    kinds <- traverse (\(label, _) -> lookup label declared) given
    zip (map fst given) <$> members kinds (map snd given)
  rebuilt = case (coreExpressionShape core, expected) of
    (CoreArray items, CoreArrayType element) -> CoreArray <$> members (map (const element) items) items
    (CoreTuple items, CoreTupleType kinds) -> CoreTuple <$> members kinds items
    (CoreRecord fields, CoreRecordType owner _)
      | CoreRecordType original _ <- actual, original == owner -> do
          declared <- recordFields types expected
          CoreRecord <$> labelled declared fields
    (CoreConstruct name fields, CoreSumType owner _)
      | CoreSumType original _ <- actual, original == owner -> do
          variants <- sumVariants types expected
          variant <- lookup name [(coreVariantName variant, variant) | variant <- variants]
          CoreConstruct name <$> labelled (coreVariantFields variant) fields
    (CoreBlockValue block, _) | Just result <- coreBlockResult block ->
      let widened = widen types expected result
       in if settled widened expected then Just (CoreBlockValue block{coreBlockResult = Just widened}) else Nothing
    (CoreIfValue condition yes no, _) ->
      let taken = widenBlock types expected yes
          other = widen types expected no
       in if maybe True (`settled` expected) (coreBlockResult taken) && settled other expected
            then Just (CoreIfValue condition taken other) else Nothing
    (CoreMatch subject arms, _) ->
      let widened = [arm{coreArmBody = widen types expected (coreArmBody arm)} | arm <- arms]
       in if all ((`settled` expected) . coreArmBody) widened then Just (CoreMatch subject widened) else Nothing
    _ -> Nothing

{-| The same, with the type the value then has. -}
widenTo :: LowerTypes -> CoreType -> (CoreExpression, CoreType) -> (CoreExpression, CoreType)
widenTo types expected (core, _) = let widened = widen types expected core in (widened, coreExpressionType widened)

{-| A block whose result widens. -}
widenBlock :: LowerTypes -> CoreType -> CoreBlock -> CoreBlock
widenBlock types expected (CoreBlock statements result) = CoreBlock statements (widen types expected <$> result)

{-| Select one native result layout per returning arm. An empty match still
    has the result expected by the caller. -}
joinRuntimeArms :: Span -> CoreType -> CoreExpression -> [CoreArm] -> CoreExpression
joinRuntimeArms at fallback subject arms =
  CoreExpression at result (CoreMatch subject (map boxed arms))
 where
  carriers = Set.toList (Set.fromList (filter (/= CoreNeverType) (map (coreExpressionType . coreArmBody) arms)))
  result = case carriers of
    [] | null arms -> fallback
       | otherwise -> CoreNeverType
    [only] -> only
    _ -> CoreSumType runtimeChoiceKey carriers
  boxed arm
    | Just alternatives <- runtimeChoiceAlternatives result
    , let value = coreArmBody arm
    , Just (tag, _) <- find ((== coreExpressionType value) . snd) alternatives =
        arm{coreArmBody = runtimeBox result tag value}
    | otherwise = arm

runtimeBox :: CoreType -> Text -> CoreExpression -> CoreExpression
runtimeBox kind tag value = CoreExpression (coreExpressionSpan value) kind (CoreConstruct tag [("0", value)])

missingRuntimeMember :: Span -> Text -> CoreExpression -> CoreExpression
missingRuntimeMember at member held = case coreExpressionType held of
  CoreSumType{} -> failedWithKind at ("no field or method " <> member <> " on a ") held
  CoreTupleType{} -> failedWithKind at ("cannot read " <> member <> " from a ") held
  kind -> CoreExpression at CoreNeverType (CoreFailText "E7001" Nothing
    (CoreExpression at CoreTextType (CoreTextLiteral ("no field or method " <> member <> " on a " <> coreTypeName kind))) Nothing)

invalidRuntimeIndex :: LowerState -> Span -> CoreExpression -> [CoreExpression] -> (LowerState, CoreExpression)
invalidRuntimeIndex state at receiver operands =
  let kind = coreExpressionType receiver
      (ready, local) = bindLocal state "" kind
      read' = CoreExpression at kind (CoreReadLocal local)
      effects = CoreStatement (coreExpressionSpan receiver) (CoreDeclare local receiver)
        : [CoreStatement (coreExpressionSpan operand) (CoreEvaluate operand) | operand <- operands]
   in (ready, CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock effects
        (Just (failedWithKind at "cannot index a " read')))))

failedWithKind :: Span -> Text -> CoreExpression -> CoreExpression
failedWithKind at prefix held =
  let text = CoreExpression at CoreTextType
      message = text (CoreBinary CoreAdd (text (CoreTextLiteral prefix)) (text (CoreRuntimeKind held)))
   in CoreExpression at CoreNeverType (CoreFailText "E7001" Nothing message Nothing)

runtimeCarriers :: CoreType -> Set.Set CoreType
runtimeCarriers CoreNeverType = Set.empty
runtimeCarriers kind = case runtimeChoiceAlternatives kind of
  Just alternatives -> foldMap (runtimeCarriers . snd) alternatives
  Nothing -> Set.singleton kind

hasRuntimeChoice :: CoreType -> Bool
hasRuntimeChoice kind = case kind of
  _ | Just _ <- runtimeChoiceAlternatives kind -> True
  CoreFunctionType inputs result -> any hasRuntimeChoice (result : inputs)
  CoreTupleType members -> any hasRuntimeChoice members
  CoreRecordType _ native -> case recordCarrierParts native of
    (_, Just _) -> True
    (members, Nothing) -> any hasRuntimeChoice members
  CoreSumType _ native -> case sumCarrierParts native of
    (_, Just _) -> True
    (members, Nothing) -> any hasRuntimeChoice members
  CoreArrayType member -> hasRuntimeChoice member
  CoreSetType member -> hasRuntimeChoice member
  CoreMapType key value -> hasRuntimeChoice key || hasRuntimeChoice value
  CoreStoreType value -> hasRuntimeChoice value
  _ -> False

runtimeResultType :: CoreType -> Set.Set CoreType -> CoreType
runtimeResultType checked carriers
  | Set.null carriers || carriers == runtimeCarriers checked = checked
  | [only] <- Set.toList carriers, hasRuntimeChoice only = only
  | otherwise = CoreSumType runtimeChoiceKey (Set.toList carriers)

preserveRuntimeResult :: CoreType -> CoreExpression -> CoreExpression
preserveRuntimeResult checked core
  | actual /= checked && actual /= CoreNeverType
  , not (hasRuntimeChoice actual) =
      runtimeBox (CoreSumType runtimeChoiceKey [actual]) "0" core
  | otherwise = core
 where
  actual = coreExpressionType core

projectRuntimeValue :: LowerTypes -> LowerState -> CoreType -> CoreExpression -> (LowerState, CoreExpression)
projectRuntimeValue types state expected core
  | expected /= actual
  , runtimeCarriers actual `Set.isSubsetOf` runtimeCarriers expected
  , Just (after, Just (mapped, _)) <- mapRuntimeChoice state (coreExpressionSpan core) expected core choose ->
      (after, mapped)
  | expected /= actual
  , hasRuntimeChoice expected
  , aggregateType expected
  , Just (ready, Just (projected, kind)) <- mapRuntimeChoice state (coreExpressionSpan core) expected core projectMember
  , kind == expected = (ready, projected)
  | expected /= actual
  , hasRuntimeChoice expected
  , Just projected <- projectProduct types state expected core = projected
  | expected /= actual
  , hasRuntimeChoice expected
  , Just projected <- projectSum types state expected core = projected
  | expected /= actual
  , hasRuntimeChoice expected
  , Just projected <- projectCollection types state expected core = projected
  | otherwise = (state, widen types expected core)
 where
  actual = coreExpressionType core
  choose current member =
    let (after, projected) = projectRuntimeValue types current expected member
     in (after, Just projected)
  projectMember current member =
    let (after, projected) = projectRuntimeValue types current expected member
     in if coreExpressionType projected == expected then (after, Just projected) else (current, Nothing)
  aggregateType CoreTupleType{} = True
  aggregateType CoreRecordType{} = True
  aggregateType (CoreSumType owner _) = owner /= runtimeChoiceKey
  aggregateType CoreArrayType{} = True
  aggregateType CoreMapType{} = True
  aggregateType CoreSetType{} = True
  aggregateType CoreStoreType{} = True
  aggregateType _ = False

normalizeAggregateValue :: LowerTypes -> Maybe CoreType -> LowerState -> CoreExpression -> (LowerState, CoreExpression)
normalizeAggregateValue types checked state value
  | Just _ <- runtimeChoiceAlternatives (coreExpressionType value)
  , Just declared <- checked
  , Just combined <- commonAggregateCarrier types declared (Set.toList (runtimeCarriers (coreExpressionType value))) =
      projectRuntimeValue types state combined value
  | otherwise = (state, value)

storageCarrier :: LowerTypes -> CoreType -> [CoreType] -> CoreType
storageCarrier types checked carriers
  | all (== checked) carriers = checked
  | Just productKind <- commonAggregateCarrier types checked carriers = productKind
  | otherwise = runtimeResultType checked (foldMap runtimeCarriers (checked : carriers))

settledMutableLayout :: LowerContext -> MutableSite -> CoreType -> CoreType
settledMutableLayout context site checked =
  storageCarrier (contextTypes context) checked
    (Set.toList (Map.findWithDefault Set.empty site (contextMutableLayouts context)))

commonAggregateCarrier :: LowerTypes -> CoreType -> [CoreType] -> Maybe CoreType
commonAggregateCarrier types checked carriers
  | any hasRuntimeChoice carriers = case checked of
      CoreTupleType members -> do
        alternatives <- traverse (tupleMembers (length members)) carriers
        pure (CoreTupleType (zipWith (storageCarrier types) members (transpose alternatives)))
      CoreRecordType owner native -> do
        fields <- recordFields types checked
        alternatives <- traverse (recordMembers owner (fst (recordCarrierParts native))) carriers
        pure (recordWithFields types checked (zipWith (storageCarrier types) (map snd fields) (transpose alternatives)))
      CoreSumType owner native | owner /= runtimeChoiceKey, not (isDynamic checked) -> do
        variants <- sumVariants types checked
        alternatives <- traverse (sumMembers owner (fst (sumCarrierParts native))) carriers
        pure (sumWithPayload types checked (zipWith (storageCarrier types) (payloadKinds variants) (transpose alternatives)))
      CoreArrayType member ->
        CoreArrayType . storageCarrier types member <$> traverse arrayMember carriers
      CoreMapType key value -> do
        slots <- traverse mapMembers carriers
        pure (CoreMapType (storageCarrier types key (map fst slots)) (storageCarrier types value (map snd slots)))
      CoreSetType member ->
        CoreSetType . storageCarrier types member <$> traverse setMember carriers
      CoreStoreType member ->
        CoreStoreType . storageCarrier types member <$> traverse storeMember carriers
      _ -> Nothing
  | otherwise = Nothing
 where
  tupleMembers size (CoreTupleType members) | length members == size = Just members
  tupleMembers _ _ = Nothing
  recordMembers owner arguments kind@(CoreRecordType name native)
    | owner == name, fst (recordCarrierParts native) == arguments = map snd <$> recordFields types kind
  recordMembers _ _ _ = Nothing
  sumMembers owner arguments kind@(CoreSumType name native)
    | owner == name, fst (sumCarrierParts native) == arguments = payloadKinds <$> sumVariants types kind
  sumMembers _ _ _ = Nothing
  arrayMember (CoreArrayType kind) = Just kind
  arrayMember _ = Nothing
  mapMembers (CoreMapType key value) = Just (key, value)
  mapMembers _ = Nothing
  setMember (CoreSetType kind) = Just kind
  setMember _ = Nothing
  storeMember (CoreStoreType kind) = Just kind
  storeMember _ = Nothing

recordWithFields :: LowerTypes -> CoreType -> [CoreType] -> CoreType
recordWithFields types kind slots = case kind of
  CoreRecordType owner native
    | let (arguments, _) = recordCarrierParts native
          declared = CoreRecordType owner arguments
    , Just fields <- recordFields types declared
    , length fields == length slots ->
        if map snd fields == slots then declared else recordCarrier owner arguments slots
  _ -> kind

payloadKinds :: [CoreVariant] -> [CoreType]
payloadKinds = concatMap (map snd . coreVariantFields)

sumWithPayload :: LowerTypes -> CoreType -> [CoreType] -> CoreType
sumWithPayload types kind slots = case kind of
  CoreSumType owner native
    | owner /= runtimeChoiceKey, not (isDynamic kind)
    , let (arguments, _) = sumCarrierParts native
          declared = CoreSumType owner arguments
    , Just variants <- sumVariants types declared
    , let payload = payloadKinds variants
    , length payload == length slots ->
        if payload == slots then declared else sumCarrier owner arguments slots
  _ -> kind

projectProduct :: LowerTypes -> LowerState -> CoreType -> CoreExpression -> Maybe (LowerState, CoreExpression)
projectProduct types state expected core = do
  (fields, build) <- case (expected, coreExpressionType core) of
    (CoreTupleType wanted, CoreTupleType actual) | length wanted == length actual ->
      Just (zipWith3 (\position to from -> (to, from, CoreTupleIndex position)) [0 ..] wanted actual, CoreTuple)
    (CoreRecordType owner left, actual@(CoreRecordType original right))
      | owner == original, fst (recordCarrierParts left) == fst (recordCarrierParts right) -> do
          wanted <- recordFields types expected
          held <- recordFields types actual
          if map fst wanted == map fst held
            then Just (zipWith (\(name, to) (_, from) -> (to, from, CoreField name)) wanted held,
              CoreRecord . zip (map fst wanted))
            else Nothing
    _ -> Nothing
  let at = coreExpressionSpan core
      (bound, local) = bindLocal state "" (coreExpressionType core)
      reading = CoreExpression at (coreExpressionType core) (CoreReadLocal local)
      project current (wanted, held, shape) =
        projectRuntimeValue types current wanted (CoreExpression at held (shape reading))
      (ready, members) = mapAccumL project bound fields
  if map coreExpressionType members == [wanted | (wanted, _, _) <- fields]
    then Just (ready, CoreExpression at expected (CoreBlockValue (CoreBlock
      [CoreStatement at (CoreDeclare local core)] (Just (CoreExpression at expected (build members))))))
    else Nothing

projectCollection :: LowerTypes -> LowerState -> CoreType -> CoreExpression -> Maybe (LowerState, CoreExpression)
projectCollection types state expected source = case (expected, coreExpressionType source) of
  (CoreArrayType new, CoreArrayType old) -> projectArray types state at old new source
  (CoreMapType key held, CoreMapType oldKey oldHeld) ->
    rebuild KeyedEntries (CoreTupleType [oldKey, oldHeld]) (CoreTupleType [key, held])
  (CoreSetType held, CoreSetType oldHeld) -> rebuild KeyedKeys oldHeld held
  (CoreStoreType held, CoreStoreType oldHeld) ->
    rebuild KeyedEntries (CoreTupleType [intType, oldHeld]) (CoreTupleType [intType, held])
  _ -> Nothing
 where
  at = coreExpressionSpan source
  rebuild method old new = do
    let entries = CoreExpression at (CoreArrayType old) (CoreKeyedMethod method source [])
    (ready, projected) <- projectArray types state at old new entries
    pure (ready, CoreExpression at expected (CoreKeyedMethod KeyedFromArray projected []))

projectArray :: LowerTypes -> LowerState -> Span -> CoreType -> CoreType -> CoreExpression -> Maybe (LowerState, CoreExpression)
projectArray types state at old new source
  | old == new = Just (state, source)
  | otherwise =
      let output = CoreArrayType new
          (withInput, input) = bindLocal state "" (CoreArrayType old)
          (withResult, result) = bindLocal withInput "" output
          (withCount, count) = bindLocal withResult "" intType
          (withIndex, index) = bindLocal withCount "" intType
          (withItem, item) = bindLocal withIndex "" old
          identity = CoreLoopId (lowerNextLoop withItem)
          entered = withItem{lowerNextLoop = lowerNextLoop withItem + 1}
          (ready, converted) = projectRuntimeValue types entered new (read' item)
          takeOutput = expression output (CoreTakeLocal result)
          condition = expression CoreBoolType (CoreBinary CoreLess (read' index) (read' count))
          turn =
            [ declare item (expression old (CoreIndex (read' input) (read' index)))
            , statement (CoreAssign result (expression output (CoreArrayMethod ArrayPushValue takeOutput [converted])))
            , statement (CoreAssign index (expression intType (CoreBinary CoreAdd (read' index) (number 1)))) ]
          setup =
            [ declare input source
            , declare result (expression output (CoreArray []))
            , declare count (expression intType (CoreArrayMethod ArrayLengthOf (read' input) []))
            , declare index (number 0)
            , statement (CoreEvaluate (expression CoreUnitType (CoreWhileValue identity condition (CoreBlock turn Nothing)))) ]
       in if coreExpressionType converted == new
            then Just (ready, expression output (CoreBlockValue (CoreBlock setup (Just (read' result)))))
            else Nothing
 where
  expression = CoreExpression at
  statement = CoreStatement at
  declare local value = statement (CoreDeclare local value)
  read' local = expression (coreLocalType local) (CoreReadLocal local)
  number value = expression intType (CoreIntegerLiteral PlatformSigned value)

projectSum :: LowerTypes -> LowerState -> CoreType -> CoreExpression -> Maybe (LowerState, CoreExpression)
projectSum types state expected core = do
  CoreSumType owner wanted <- Just expected
  CoreSumType original held <- Just (coreExpressionType core)
  if owner /= original || fst (sumCarrierParts wanted) /= fst (sumCarrierParts held)
    || owner == runtimeChoiceKey || isDynamic expected then Nothing else do
      source <- sumVariants types (coreExpressionType core)
      target <- sumVariants types expected
      let (ready, arms) = mapAccumL project state (zip source target)
      lowered <- sequence arms
      pure (ready, CoreExpression at expected (CoreMatch core lowered))
 where
  at = coreExpressionSpan core
  project current (source, target)
    | coreVariantName source /= coreVariantName target || map fst actual /= map fst wanted = (current, Nothing)
    | otherwise =
        let (bound, locals) = mapAccumL (\prior (_, kind) -> bindLocal prior "" kind) current actual
            read' local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
            carry prior ((_, kind), local) = projectRuntimeValue types prior kind (read' local)
            (ready, values) = mapAccumL carry bound (zip wanted locals)
            name = coreVariantName source
            payload = zip (map fst wanted) values
            pattern' = CoreVariantPattern name (map CoreBindPattern locals)
         in if map coreExpressionType values == map snd wanted
              then (ready, Just (CoreArm at pattern' Nothing (CoreExpression at expected (CoreConstruct name payload))))
              else (current, Nothing)
   where
    actual = coreVariantFields source
    wanted = coreVariantFields target

mapRuntimeChoice
  :: LowerState -> Span -> CoreType -> CoreExpression
  -> (LowerState -> CoreExpression -> (LowerState, Maybe CoreExpression))
  -> Maybe (LowerState, Maybe (CoreExpression, CoreType))
mapRuntimeChoice state at fallback subject consume = select state [] <$> runtimeChoiceAlternatives (coreExpressionType subject)
 where
  select current arms [] =
    let joined = joinRuntimeArms at fallback subject (reverse arms)
     in (current, Just (joined, coreExpressionType joined))
  select current arms ((tag, kind) : rest) =
    let (bound, local) = bindLocal current "" kind
        reading = CoreExpression at kind (CoreReadLocal local)
     in case consume bound reading of
          (after, Just result) ->
            let arm = CoreArm at (CoreVariantPattern tag [CoreBindPattern local]) Nothing result
             in select after (arm : arms) rest
          (after, Nothing) -> refused after
