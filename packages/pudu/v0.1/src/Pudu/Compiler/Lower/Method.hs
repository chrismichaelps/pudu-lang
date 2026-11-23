{-| @Pudu.Compiler.Lower.Method — implementation members and trait defaults
    as ordinary native calls, selected by the receiver's checked type. -}
module Pudu.Compiler.Lower.Method (methodTables, lowerMethodCall, lowerHeldMethod, lowerQualifiedMethod, lowerOwnedMethod, callInstance) where

import Data.Map.Strict (Map)
import Data.List (mapAccumL)
import Control.Applicative ((<|>))
import qualified Data.Map.Strict as Map
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Arguments (methodArgumentBlame)
import Pudu.Compiler.Lower.Control (blockType, expressionIsPrintValued)
import Pudu.Compiler.Lower.Default (callArityFailure, suppliedArguments, takesSuppliedCount)
import Pudu.Compiler.Lower.Scalar (eagerType, namedFailure)
import Pudu.Compiler.Lower.Signature (ensureSignature)
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), Head (..), Instance (..), LowerContext (..), LowerState (..), ModuleScope (..)
  , bindLocal, halt, inModule, refused, withTypeBindings )
import Pudu.Compiler.Lower.Generic (instantiationOf, matchType, runtimeCallSignature, specialize, unformed)
import Pudu.Compiler.Lower.Dynamic (commonAggregateCarrier, hasRuntimeChoice, isDynamic, joinRuntimeArms, mapRuntimeChoice, pathText, preserveRuntimeResult, projectRuntimeValue, runtimeCarriers, widen, writtenType)
import Pudu.Compiler.Lower.Loan (Callee (..), Operand (..), loanedType, lowerLoanedOperands)
import Pudu.Compiler.Lower.MethodValue (boundMemberFact, declaredMemberType, lowerDynamicTextCall)
import Pudu.Compiler.Lower.Place (HeldPlace (..), holdPlace, observeHeldLayout, readHeld, readHeldAtKeys, storeHeld, withMemberReceiver)
import Pudu.Compiler.Lower.Types (formedCoreTypeIn, loanedInputs, lookupScheme, ownerKeyOf, recordFields, selectedMember, sumVariants, typeBindings, typeFactAt, typeForSpan, nativeValueType)
import Pudu.Core
import Pudu.Eval.Operator.Access (arrayMethods, mapMethods, setMethods, stringMethods)
import Pudu.Eval.Bytes (bytesMethods)
import Pudu.Eval.HashMap (bucketsMethods)
import Pudu.Frontend.Syntax
  ( Declaration (..), Expression (..), Constraint (..), Function (..), Impl (..), Located (..), Module (..), Parameter (..), Trait (..), TypeParam (..), TypeSyntax (..) )
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Source (Span)
import Pudu.Type.Value (NominalId (..), Scheme (..), Type (..), nominalKey)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

type Redispatch = LowerState -> CoreExpression -> Maybe HeldPlace -> Lowered

{-| Every method checking declared, as an instance keyed by owner, trait and
    member, with the indexes a call reaches it through. A member is found by
    the span of its name: an implementation's own function, or the trait
    member it inherits, which then runs with `Self` bound to the owner.
    A generic implementation's members, and the defaults a generic owner
    inherits, are specialized at each call. -}
methodTables
  :: Map Text ModuleScope
  -> [(Text, Module, [(NominalId, Text, Scheme, Span)])]
  -> (Map Text Instance, Map (Text, Text) Text, Map (Text, Text, Text) Text, Map (Text, Text) Head)
methodTables scopes modules = (Map.fromList instances, Map.fromList calls, Map.fromList qualified, Map.fromList heads)
 where
  -- Every implementation of a trait, by the trait's name and the owner's key.
  heads =
    [ ((trait, pathText target), Head owner arguments bounds)
    | (_, syntax, _) <- modules
    , Located _ (ImplDeclaration impl) <- moduleDeclarations syntax
    , NamedType target _ <- [locatedValue (implTarget impl)]
    , NamedType provider written <- [locatedValue (implTrait impl)]
    , trait <- [pathText provider, lastSegment (implTrait impl)]
    , let rigid = map (locatedValue . typeParamName . locatedValue) (implTypeParams impl)
    , Just owner <- [resolvedType rigid (implTarget impl)]
    , Just arguments <- [traverse (resolvedType rigid) written]
    , let bounds =
            [ (locatedValue (typeParamName parameter), held)
            | Located _ parameter <- implTypeParams impl
            , Just held <- [traverse (resolvedType rigid) (typeParamBounds parameter)], not (null held) ] <>
            [ (locatedValue (constraintSubject constraint), held)
            | Located _ constraint <- implConstraints impl
            , Just held <- [traverse (resolvedType rigid) (constraintBounds constraint)], not (null held) ]
    ]
  entries =
    [ (key, Instance declaring function scheme bindings (inherited && Map.null selfBinding) derived, (ownerKey, name), (provider, ownerKey, name))
    | (moduleName, syntax, methods) <- modules
    , (owner, name, scheme, at) <- methods
    , Just (declaring, provider, function, inherited) <- [declaredAnywhere at]
    , let traitText = displayName provider
          ownerKey = nominalKey owner
          key = ownerKey <> "." <> provider <> "." <> name
          implementing = scopeTypes <$> Map.lookup moduleName scopes
          self = implementing >>= \types -> formedCoreTypeIn types (NominalType owner [])
          selfBinding = maybe Map.empty (Map.singleton "Self") self
          derived
            | inherited = Map.union (headArguments syntax owner declaring traitText) (traitArguments declaring traitText name scheme)
            | otherwise = Map.empty
          bindings = selfBinding
    ]
  instances = [(key, found) | (key, found, _, _) <- entries]
  calls = [(call, key) | (key, _, call, _) <- entries]
  qualified = [((trait, owner, member), key) | (key, _, _, (provider, owner, member)) <- entries
    , trait <- [provider, displayName provider]]

  -- The body and implementation have separate rigid namespaces. Keep the
  -- matched body bindings unformed until the implementation's parameters
  -- settle, including when both scopes use the same spelling.
  traitArguments declaring traitText name scheme = Map.fromList
    [ (parameter, held)
    | Just declared <- [declaredMember declaring traitText name]
    , Just matched <- [matchType (schemeType declared) (schemeType scheme) Map.empty]
    , (parameter, held) <- Map.toList matched
    , parameter /= "Self"
    ]

  -- Implementation heads already carry canonical checked identities and
  -- arguments, including parameters absent from this member's signature.
  headArguments syntax owner declaring traitText = Map.fromList
    [ (locatedValue (typeParamName (locatedValue parameter)), held)
    | (_, tree, _) <- modules
    , moduleNameOf tree == declaring
    , Located _ (TraitDeclaration trait) <- moduleDeclarations tree
    , locatedValue (traitName trait) == traitText
    , Located _ (ImplDeclaration impl) <- moduleDeclarations syntax
    , NamedType target _ <- [locatedValue (implTarget impl)]
    , pathText target == nominalKey owner
    , NamedType provider arguments <- [locatedValue (implTrait impl)]
    , pathText provider == declaring <> "." <> traitText
    , (parameter, argument) <- zip (traitTypeParams trait) arguments
    , Just held <- [resolvedType (map (locatedValue . typeParamName . locatedValue) (implTypeParams impl)) argument]
    ]
  moduleNameOf = pathText . locatedValue . moduleName
  resolvedType = writtenType

  declaredMember declaring traitText name = case
    [ found
    | Just scope <- [Map.lookup declaring scopes]
    , candidate <- [declaring <> "." <> traitText <> "." <> name, traitText <> "." <> name]
    , Just found <- [lookupScheme (scopeTypes scope) candidate] ] of
      found : _ -> Just found
      [] -> Nothing

  -- A default inherited from an imported trait is declared in the trait's
  -- module, so its body lowers there, where its names resolve, as the
  -- evaluator runs it in that module's scope. Spans name their source, so one
  -- declaration answers.
  declaredAnywhere at = case
    [ (moduleName, provider, function, inherited)
    | (moduleName, syntax, _) <- modules
    , Just (provider, function, inherited) <- [declaredAt moduleName (moduleDeclarations syntax) at] ] of
      found : _ -> Just found
      [] -> Nothing

  declaredAt moduleName declarations at = case
    [ (pathText provider, function, False)
    | Located _ (ImplDeclaration impl) <- declarations
    , NamedType provider _ <- [locatedValue (implTrait impl)]
    , function <- implFunctions impl, locatedSpan (functionName (locatedValue function)) == at ] <>
    [ (moduleName <> "." <> locatedValue (traitName trait), member, True)
    | Located _ (TraitDeclaration trait) <- declarations
    , member <- traitMembers trait, locatedSpan (functionName (locatedValue member)) == at ] of
      found : _ -> Just found
      [] -> Nothing

  lastSegment (Located _ syntax) = case syntax of
    NamedType (ModuleName segments) _ -> NonEmpty.last segments
    _ -> ""

{-| `receiver.member(arguments)` when the receiver's type has that method, or
    `toText()` on a type that declares none. Str and Char answer their own
    built-in members first, as the evaluator reads them; Nothing leaves the
    call to the built-in method lowering. -}
lowerHeldMethod :: LowerExpression -> Span -> Text -> [Located Expression]
  -> LowerState -> CoreExpression -> Maybe HeldPlace -> Maybe Lowered
lowerHeldMethod lower at member arguments state value place = do
  let context = lowerContext state
      kind = coreExpressionType value
      selectedFact = declaredMemberType context kind member >>= boundMemberFact kind
      instantiated = selectedFact >>= bindMemberReceiver (unformed kind)
  key <- declaredMethodKey context kind member
  pure (callMemberInstance lower state at key instantiated value place arguments)

lowerMethodCall :: LowerExpression -> Redispatch -> LowerState -> Span -> Span -> Located Expression -> Text -> [Located Expression] -> Maybe Lowered
lowerMethodCall lower redispatch state at callee receiver written arguments = do
  kind <- typeForSpan (contextTypes context) (locatedSpan receiver)
  if isDynamic kind then Just (if written == "toText" && null arguments
    then lowerDynamicTextCall lower state at callee receiver kind
    else dynamicCall lower state at kind receiver member (typeFactAt (contextTypes context) callee) arguments)
  else case declaredMethodKey context kind written of
    Just key ->
      Just (callMethod lower redispatch state at kind key instantiated receiver arguments)
    _ | not (builtinFirst member kind), member == "toText", null arguments ->
          case recordFields (contextTypes context) kind >>= lookup member of
            Nothing -> Just (rendered kind)
            Just field
              | uncallable field, Just FunctionTypeRequiring{} <- typeFactAt (contextTypes context) callee ->
                  Just (failedField field)
            _ -> Nothing
      | otherwise -> Nothing
 where
  context = lowerContext state
  member = snd (selectedMember written)
  instantiated = do
    fact <- typeFactAt (contextTypes context) callee
    held <- typeFactAt (contextTypes context) (locatedSpan receiver)
    bindMemberReceiver held fact
  uncallable kind = case kind of
    CoreFunctionType{} -> False
    CoreSumType{} -> False
    CoreCallbackType{} -> False
    _ -> nativeValueType kind
  failedField field = case lower state receiver of
    (after, Nothing) -> refused after
    (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
    (after, Just (core, _)) ->
      namedFailure after at (("cannot call a " <>) . mconcat) [CoreExpression at field (CoreField member core)]
  rendered kind = withMemberReceiver lower state at receiver $ \after core place ->
    if expressionIsPrintValued core
      then halt at "toText of a Result[(), Str] value" after
      else if nativeValueType kind
        then redispatch after core place
        else halt at ("toText of a " <> coreTypeName kind <> " value") after

bindMemberReceiver :: Type -> Type -> Maybe Type
bindMemberReceiver held (FunctionTypeRequiring asynchronous inputs required result) =
  Just (FunctionTypeRequiring asynchronous (held : inputs) required result)
bindMemberReceiver _ _ = Nothing

declaredMethodKey :: LowerContext -> CoreType -> Text -> Maybe Text
declaredMethodKey context kind written
  | member /= "toText", builtinFirst member kind = Nothing
  | otherwise = do
      owner <- ownerKeyOf kind
      let qualified = provider >>= \trait -> Map.lookup (trait, owner, member) (contextTraitMethods context)
      qualified <|> Map.lookup (owner, member) (contextMethods context)
 where
  (provider, member) = selectedMember written

builtinFirst :: Text -> CoreType -> Bool
builtinFirst member kind = case kind of
  CoreTextType -> member `elem` map fst stringMethods
  CoreCharType -> member `elem` ["code", "toText"]
  CoreArrayType _ -> member `elem` map fst arrayMethods
  CoreMapType _ _ -> member `elem` map fst mapMethods
  CoreSetType _ -> member `elem` map fst setMethods
  CoreStoreType _ -> member `elem` map fst bucketsMethods
  CoreBytesType -> member `elem` map fst bytesMethods
  _ -> False

{-| A method of a dynamic value: the receiver runs, then the arguments, and
    the type it holds answers with its own implementation of the trait. -}
dynamicCall :: LowerExpression -> LowerState -> Span -> CoreType -> Located Expression -> Text -> Maybe Type -> [Located Expression] -> Lowered
dynamicCall lower state at kind receiver member checked arguments = case receiving of
  (after, Nothing) -> refused after
  (after, Just (receiverPrelude, coreReceiver, _))
    | stopsAt receiverPrelude coreReceiver ->
        stopped after (receiverPrelude <> [CoreStatement (coreExpressionSpan coreReceiver) (CoreEvaluate coreReceiver)])
  (after, Just (receiverPrelude, coreReceiver, receiverPlace)) -> case operandsOf after [] (zip [0 ..] arguments) of
    (final, Nothing) -> refused final
    (final, Just operands) ->
      let pushed = final{lowerScopes = [] : lowerScopes final}
          (withReceiver, receiverLocal) = bindLocal pushed "" (coreExpressionType coreReceiver)
          cores = [core | (_, core, _) <- operands]
          (bound, temporaries) = foldl' hold (withReceiver, []) cores
          declarations = receiverPrelude <> [CoreStatement (coreExpressionSpan coreReceiver) (CoreDeclare receiverLocal coreReceiver)]
            <> concat [prelude <> [CoreStatement (coreExpressionSpan core) (CoreDeclare local core)] | ((prelude, core, _), local) <- zip operands temporaries]
          scrutinee = CoreExpression (coreExpressionSpan coreReceiver) (coreLocalType receiverLocal) (CoreReadLocal receiverLocal)
          passed = [CoreExpression (coreExpressionSpan core) (coreLocalType local) (CoreReadLocal local) | (local, core) <- zip temporaries cores]
          -- Parameter positions lent through a place, the receiver at zero
          -- when its method takes `&mut self`; a receiver that is no place is
          -- lent a copy whose final is dropped.
          lentArguments = [(position, Just found) | (position, (_, _, Just found)) <- zip [1 ..] operands]
          lent = [(0, receiverPlace) | selfLent] <> lentArguments
          close next = next{lowerScopes = drop 1 (lowerScopes next)}
       in if blockType declarations Nothing == CoreNeverType
          then stopped (close bound) declarations
          else case foldl' (arm (map fst lent) passed) (bound, Just []) variants of
            (done, Just arms@(first : _)) ->
              let firstKind = coreExpressionType (coreArmBody first)
               in if null lent
                    then let chosen = joinRuntimeArms at firstKind scrutinee (reverse arms)
                             answered = coreExpressionType chosen
                          in (close done, Just (CoreExpression at answered (CoreBlockValue (CoreBlock declarations (Just chosen))), answered))
                    else let (ready, result) = publishDynamicFinals at done declarations scrutinee lent firstKind (reverse arms)
                          in (close ready, result)
            -- Nothing implements the trait, so no value reaches this call:
            -- the match has no arm, at the type checking gave the call.
            (done, Just []) -> case typeForSpan (contextTypes (lowerContext done)) at of
              Just answered | nativeValueType answered ->
                ( close done
                , Just (CoreExpression at answered (CoreBlockValue (CoreBlock declarations
                    (Just (CoreExpression at answered (CoreMatch scrutinee []))))), answered) )
              _ -> halt at "a method of a dynamic value no type implements" (close done)
            (done, Nothing) -> refused (close done)
 where
  targetOf current payload = do
    CoreSumType key _ <- Just kind
    trait <- Text.stripPrefix "dynamic." key
    owner <- ownerKeyOf payload
    Map.lookup (trait, owner, member) (contextTraitMethods (lowerContext current))
  variants = maybe [] id (sumVariants (contextTypes (lowerContext state)) kind)
  -- Every implementation shares the trait's signature, so the first one says
  -- whether the method takes `&mut self`.
  (probed, selfLent) = case [(key, payload) | variant <- variants, [(_, payload)] <- [coreVariantFields variant]
                                            , Just key <- [targetOf state payload]] of
    (key, payload) : _ -> case instanceTarget state at key (heldBy payload) [payload] unselected of
      (back, Just (_, signature)) -> (back, 0 `elem` signatureLoaned signature)
      (back, Nothing) -> (back, False)
    [] -> (state, False)
  -- A receiver lent with `&mut self` resolves its place once, as a lent
  -- argument does; otherwise it is an ordinary value.
  receiving
    | selfLent, Just held <- holdPlace lower probed (locatedSpan receiver) receiver = case held of
        (after, Nothing) -> (after, Nothing)
        (after, Just (prelude, found)) ->
          fmap (fmap (\(value, _) -> (prelude, value, Just found))) (readHeldAtKeys after found)
    | otherwise = case lower probed receiver of
        (after, Nothing) -> (after, Nothing)
        (after, Just (core, _)) -> (after, Just ([], core, Nothing))
  hold (current, held) core =
    let (next, local) = bindLocal current "" (coreExpressionType core)
     in (next, held <> [local])
  stopsAt prelude core = coreExpressionType core == CoreNeverType || blockType prelude Nothing == CoreNeverType
  stopped current declarations =
    (current, Just (CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock declarations Nothing)), CoreNeverType))
  -- A loan can name a place explicitly or forward a lent parameter.
  operandsOf current done [] = (current, Just (reverse done))
  operandsOf current done ((position, argument) : rest)
    | Just place <- argumentPlace position argument
    , Just held <- holdPlace lower current (locatedSpan place) place =
        case held of
          (after, Nothing) -> (after, Nothing)
          (after, Just (prelude, found)) -> case readHeld after found of
            (ready, Just (value, _)) -> next ready prelude value (Just found)
            (ready, Nothing) -> (ready, Nothing)
    | otherwise = case lower current argument of
      (after, Nothing) -> (after, Nothing)
      (after, Just (core, _))
        | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] call argument" after
        | otherwise -> next after [] core Nothing
   where
    next after prelude core place
      | stopsAt prelude core = (after, Just (reverse collected))
      | otherwise = operandsOf after collected rest
     where
      collected = (prelude, core, place) : done
  argumentPlace position argument = case locatedValue argument of
    UnaryExpression "&mut" inner -> Just inner
    NameExpression names | length names == 1, position `elem` maybe [] loanedInputs checked -> Just argument
    _ -> Nothing
  -- The call's checked type, with the held type in front as the receiver:
  -- a generic method's own parameters settle from it, as an ordinary call's do.
  heldBy payload = case checked of
    Just (FunctionTypeRequiring asynchronous inputs required result) ->
      Just (FunctionTypeRequiring asynchronous (unformed payload : inputs) required result)
    _ -> Nothing
  arm _ _ (current, Nothing) _ = (current, Nothing)
  arm lent passed (current, Just arms) variant = case coreVariantFields variant of
    [(_, payload)] | Just key <- targetOf current payload ->
      let (withHeld, held) = bindLocal current "" payload
          reading = CoreExpression at payload (CoreReadLocal held)
          pattern' = CoreVariantPattern (coreVariantName variant) [CoreBindPattern held]
       in case (if null lent then invoke else invokeLent lent) withHeld at key (heldBy payload) unselected (reading : passed) of
            (next, Just (call, CoreTupleType (result : payloadFinal : rest))) | 0 `elem` lent ->
              -- The final receiver goes back as the dynamic value, wrapped in
              -- this arm's variant, so every arm answers one tuple type.
              let (withCall, called) = bindLocal next "" (coreExpressionType call)
                  readCall = CoreExpression at (coreExpressionType call) (CoreReadLocal called)
                  member' position kind' = CoreExpression at kind' (CoreTupleIndex position readCall)
                  (converted, wrapped) = projectRuntimeValue (contextTypes (lowerContext withCall))
                    withCall kind (member' 1 payloadFinal)
                  answered = CoreTupleType (result : kind : rest)
                  tuple = CoreExpression at answered (CoreTuple (member' 0 result : wrapped : [member' position kind' | (position, kind') <- zip [2 ..] rest]))
                  body = CoreExpression at answered (CoreBlockValue (CoreBlock [CoreStatement at (CoreDeclare called call)] (Just tuple)))
               in if coreExpressionType wrapped == kind
                    then (converted, Just (CoreArm at pattern' Nothing body : arms))
                    else halt at "a dynamic receiver final without its trait layout" converted
            (next, Just (call, _)) -> (next, Just (CoreArm at pattern' Nothing call : arms))
            (next, Nothing) -> (next, Nothing)
    _ -> halt at ("the method '" <> member <> "' of a dynamic value") current

publishDynamicFinals :: Span -> LowerState -> [CoreStatement] -> CoreExpression
  -> [(Int, Maybe HeldPlace)] -> CoreType -> [CoreArm] -> Lowered
publishDynamicFinals at state declarations subject lent checked arms
  | CoreTupleType (result : finals) <- shared
  , let project current arm =
          let (ready, value) = projectRuntimeValue types current shared (coreArmBody arm)
           in (ready, arm{coreArmBody = value})
        (ready, projectedArms) = mapAccumL project state arms
  , all ((== shared) . coreExpressionType . coreArmBody) projectedArms =
      let chosen = CoreExpression at shared (CoreMatch subject projectedArms)
          (bound, answer) = bindLocal ready "" shared
          read' = CoreExpression at shared (CoreReadLocal answer)
          publish current (index, ((_, place), finalKind)) = case place of
            Nothing -> (current, Just [])
            Just found ->
              let value = CoreExpression (heldSpan found) finalKind (CoreTupleIndex index read')
                  (next, carried) = projectRuntimeValue types current (heldType found) value
               in if coreExpressionType carried == heldType found
                    then (next, Just [storeHeld types (heldSpan found) found carried])
                    else (observeHeldLayout next found (coreExpressionType carried), Nothing)
          (final, stores) = mapAccumL publish bound (zip [1 ..] (zip lent finals))
          value = CoreExpression at result (CoreTupleIndex 0 read')
       in case sequence stores of
            Just writes ->
              let whole = CoreBlock (declarations <> [CoreStatement at (CoreDeclare answer chosen)] <> concat writes) (Just value)
               in (final, Just (CoreExpression at result (CoreBlockValue whole), result))
            Nothing -> halt at "a lent dynamic call with incompatible writeback layouts" final
  | otherwise = halt at "a lent dynamic call without compatible final layouts" state
 where
  types = contextTypes (lowerContext state)
  shared = maybe checked id (commonAggregateCarrier types checked (map (coreExpressionType . coreArmBody) arms))

{-| A call to an instance whose `&mut` parameters are exactly the lent
    positions, answering its result beside each final as a loaned body
    does. -}
invokeLent :: [Int] -> LowerState -> Span -> Text -> Maybe Type -> Selected -> [CoreExpression] -> Lowered
invokeLent lent state at key written selected given = case instanceTarget state at key instantiated (coreExpressionType <$> take 1 given) selected of
  (back, Nothing) -> refused back
  (back, Just (target, signature@CoreSignature{signatureParameters, signatureLoaned}))
    | Just failure <- callArityFailure (methodArgumentBlame back) at signature (length given) ->
        failedInvocation back at given failure
    | signatureLoaned /= lent -> halt at "a dynamic call lending other places than its method's &mut parameters" back
    | otherwise ->
        let context = lowerContext back
            layouts = map (coreLocalType . coreParameterLocal) signatureParameters
            widenArgument index expected value
              | index `elem` lent = value
              | otherwise = widen (contextTypes context) expected value
            supplied = zipWith3 widenArgument [0 ..] layouts given
            copied = do
              found <- Map.lookup target (contextInstances context)
              runtimeCallSignature (instanceModule found, instanceFunction found) back target signature (map coreExpressionType supplied)
            (ready, name, exact) = maybe (back, target, signature) id copied
            expected = map (coreLocalType . coreParameterLocal) (signatureParameters exact)
            (projected, cores) = mapAccumL (\current (kind, value) ->
              projectRuntimeValue (contextTypes context) current kind value) ready (zip expected supplied)
            operands = methodOperands at exact cores
            queued = projected{lowerContext = (lowerContext projected){contextQueue = name : contextQueue (lowerContext projected)}}
            answered = loanedType exact
         in if map coreExpressionType operands == expected
              then (queued, Just (CoreExpression at answered (CoreCall name operands), answered))
              else halt at "a dynamic loaned call with incompatible argument layouts" projected
 where
  instantiated = written <|> (Map.lookup key (contextInstances (lowerContext state)) >>= \found ->
    instantiationOf (instanceScheme found) (map coreExpressionType given))

{-| `Owner.member(arguments)`: by the type that implements it or the trait
    that declares it. The receiver is an ordinary first argument here, so the
    arguments simply run in order. The trait form picks the implementation
    for the first argument's type, as the evaluator does. -}
lowerQualifiedMethod :: LowerExpression -> LowerState -> Span -> Span -> Text -> Text -> [Located Expression] -> Maybe Lowered
lowerQualifiedMethod lower held at callee owner written arguments =
  lowerOwnerMethod lower state at callee (maybe owner id (bound >>= ownerKeyOf)) (Selected bound (lowerTypeArguments held)) written arguments
 where
  state = held{lowerTypeArguments = []}
  -- A type parameter in qualifier position, `T.made()` in a generic copy,
  -- names the type this copy binds it to, as the evaluator's witness does.
  bound = Map.lookup owner (typeBindings (contextTypes (lowerContext state)))

{-| `Option[Str].decode(json)`: the owner is a type written in full, as
    elaboration writes a static call whose implementation it selected. -}
lowerOwnedMethod :: LowerExpression -> LowerState -> Span -> Span -> CoreType -> Text -> [Located Expression] -> Maybe Lowered
lowerOwnedMethod lower state at callee kind written arguments = do
  owner <- ownerKeyOf kind
  lowerOwnerMethod lower state{lowerTypeArguments = []} at callee owner (Selected (Just kind) []) written arguments

{-| What a qualified call says beyond its operands: the type a parameter in
    qualifier position stands for, and the type arguments written on it. -}
data Selected = Selected
  { selectedOwner :: !(Maybe CoreType)
  , selectedArguments :: ![CoreType]
  }

unselected :: Selected
unselected = Selected Nothing []

lowerOwnerMethod :: LowerExpression -> LowerState -> Span -> Span -> Text -> Selected -> Text -> [Located Expression] -> Maybe Lowered
lowerOwnerMethod lower state at callee owner selected written arguments = do
  key <- case valueProvider of
    Just provider -> traitMember provider
    Nothing -> byTrait `orElse` byType
  Just $ maybe (ordinary key) id $ loanedInstanceCall lower state at key (typeFactAt (contextTypes context) callee)
    (maybe [] pure receiverType) selection [(index, Argument, argument) | (index, argument) <- zip [0 ..] arguments]
 where
  ordinary key = case lowerAll lower state arguments of
    (after, Nothing) -> refused after
    (after, Just cores) -> invoke after at key (typeFactAt (contextTypes context) callee) selection cores
  context = lowerContext state
  receiverType = case arguments of
    first : _ -> typeForSpan (contextTypes context) (locatedSpan first)
    [] -> Nothing
  receiverKey = receiverType >>= ownerKeyOf
  member = snd (selectedMember written)
  valueProvider = Text.stripPrefix "::trait-method::." owner
  selection = case valueProvider of
    Just _ -> selected{selectedOwner = receiverType}
    Nothing -> selected
  traitMember provider = receiverKey >>= \found -> Map.lookup (provider, found, member) (contextTraitMethods context)
  byTrait = traitMember owner `orElse` traitMember (displayName owner)
  -- Checking names a type by its canonical key; the source by its own name.
  names ownerKey = ownerKey == owner || displayName ownerKey == owner
  candidates = [key | ((ownerKey, name), key) <- Map.toList (contextMethods context), name == member, names ownerKey]
  byType = case [key | Just found <- [receiverKey], ((ownerKey, name), key) <- Map.toList (contextMethods context), name == member, ownerKey == found, names ownerKey] of
    key : _ -> Just key
    [] -> case candidates of
      [only] -> Just only
      _ -> Nothing
  orElse (Just found) _ = Just found
  orElse Nothing other = other

{-| Read the receiver and retain its place before selecting a member. -}
callMethod :: LowerExpression -> Redispatch -> LowerState -> Span -> CoreType -> Text -> Maybe Type
  -> Located Expression -> [Located Expression] -> Lowered
callMethod lower redispatch state at expected key instantiated receiver arguments =
  withMemberReceiver lower state at receiver $ \after value place ->
    if expressionIsPrintValued value
      then halt (locatedSpan receiver) "a Result[(), Str] method receiver" after
      else
        let (ready, chosen) = select after value place
            checked = typeForSpan (contextTypes (lowerContext ready)) at
            finish (answer, _) =
              let carried = maybe answer (\declared -> preserveRuntimeResult declared answer) checked
               in (carried, coreExpressionType carried)
         in (ready, finish <$> chosen)
 where
  differs held = ownerKeyOf held /= ownerKeyOf expected
    || not (hasRuntimeChoice held) && unformed held /= unformed expected
  select current value place
    | Just selected <- mapRuntimeChoice current at CoreNeverType value
        (\ready held -> fmap (fmap fst) (select ready held place)) = selected
    | differs (coreExpressionType value) = redispatch current value place
    | otherwise = callMemberInstance lower current at key instantiated value place arguments

callMemberInstance :: LowerExpression -> LowerState -> Span -> Text -> Maybe Type -> CoreExpression
  -> Maybe HeldPlace -> [Located Expression] -> Lowered
callMemberInstance lower state at key instantiated receiver place arguments =
  case instanceTarget state at key instantiated [coreExpressionType receiver] unselected of
    (admitted, Just (target, signature))
      | not (null (signatureLoaned signature)) ->
          lowerLoanedOperands lower admitted at (DirectMember target receiver place)
            signature (takesSuppliedCount signature)
            [(index, Argument, argument) | (index, argument) <- zip [1 ..] arguments]
    _ -> case lowerAll lower state arguments of
      (after, Nothing) -> refused after
      (after, Just cores) -> invoke after at key instantiated unselected (receiver : cores)

{-| A call to an instance: its signature is admitted in its own module under
    its own bindings, then the caller's are restored. An instance with open
    parameters is specialized first, against the instantiation at the call. -}
invoke :: LowerState -> Span -> Text -> Maybe Type -> Selected -> [CoreExpression] -> Lowered
invoke state at _ _ _ given
  | any ((== CoreNeverType) . coreExpressionType) given =
      let prelude = [CoreStatement (coreExpressionSpan value) (CoreEvaluate value) | value <- given]
       in (state, Just (CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock prelude Nothing)), CoreNeverType))
invoke state at key written selected given = case instanceTarget state at key instantiated (coreExpressionType <$> take 1 given) selected of
  (back, Nothing) -> refused back
  (back, Just (target, signature@CoreSignature{signatureLoaned}))
    | Just failure <- callArityFailure (methodArgumentBlame back) at signature (length given) ->
        failedInvocation back at given failure
    | position : _ <- signatureLoaned -> halt (loanSpan back target position) "a method with &mut parameters" back
    | otherwise ->
        let types = contextTypes (lowerContext back)
            (projected, cores) = project types back signature given
            selectedCopy = do
              instance' <- Map.lookup target (contextInstances (lowerContext projected))
              runtimeCallSignature (instanceModule instance', instanceFunction instance') projected target signature (map coreExpressionType cores)
         in case selectedCopy of
              Just (copy, name, exact) ->
                let (ready, arguments) = project types copy exact cores
                 in queue ready name exact arguments
              Nothing -> queue projected target signature cores
 where
  project types current signature cores = mapAccumL
    (\prior (expected, core) -> projectRuntimeValue types prior expected core)
    current (zip (map (coreLocalType . coreParameterLocal) (signatureParameters signature)) cores)
  queue current target signature cores =
    let queued = current{lowerContext = (lowerContext current){contextQueue = target : contextQueue (lowerContext current)}}
        result = eagerType (signatureResult signature) cores
     in (queued, Just (CoreExpression at result (CoreCall target (methodOperands at signature cores)), result))
  instantiated = written <|> (Map.lookup key (contextInstances (lowerContext state)) >>= \found ->
    instantiationOf (instanceScheme found) (map coreExpressionType given))
  -- A loan this call form cannot lend is refused where its `&mut` type is written.
  loanSpan current target position = case Map.lookup target (contextInstances (lowerContext current)) of
    Just found | Located _ parameter : _ <- drop position (functionParameters (locatedValue (instanceFunction found)))
               , Just annotated <- parameterType parameter -> locatedSpan annotated
    _ -> at

methodOperands :: Span -> CoreSignature -> [CoreExpression] -> [CoreExpression]
methodOperands at signature given
  | takesSuppliedCount signature =
      suppliedArguments at (map (coreLocalType . coreParameterLocal) (signatureParameters signature)) given
  | otherwise = given

failedInvocation :: LowerState -> Span -> [CoreExpression] -> CoreExpression -> Lowered
failedInvocation state at given failure =
  let effects = [CoreStatement (coreExpressionSpan value) (CoreEvaluate value) | value <- given]
      stopped = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock effects (Just failure)))
   in (state, Just (stopped, CoreNeverType))

{-| The instance a call reaches and its admitted signature. An instance with
    open parameters is specialized first, against the instantiation at the
    call; the signature is admitted in its own module under its own
    bindings, then the caller's are restored. -}
instanceTarget :: LowerState -> Span -> Text -> Maybe Type -> [CoreType] -> Selected -> (LowerState, Maybe (Text, CoreSignature))
instanceTarget state at key instantiated receiver selected = case Map.lookup key (contextInstances context) of
  Nothing -> halt at "this method" state
  Just found
    | open found -> case (instantiated <|> schemeInstantiation found) >>= specialize state key (instanceModule found) (instanceFunction found) (instanceScheme found) (fixed found) (instanceDerived found) of
        Just (registered, copy, _) -> instanceTarget registered at copy Nothing receiver unselected
        Nothing -> halt at "a generic method without settled type arguments" state
  Just found ->
    let entered = withTypeBindings (instanceBindings found) (inModule (instanceModule found) state)
        (admitted, signature) = ensureSignature key (instanceFunction found) entered
        back = withTypeBindings (typeBindings (contextTypes context)) (inModule (contextModule context) admitted)
     in (back, (,) key <$> signature)
 where
  context = lowerContext state
  open found = instanceSelfAtCall found
    || not (Map.null (instanceDerived found))
    || any ((`Map.notMember` instanceBindings found) . fst) (schemeParams (instanceScheme found))
  fixed found = Map.union (written found) (Map.union (owned found) (case (selectedOwner selected, receiver) of
    (Just kind, _) | instanceSelfAtCall found -> Map.insert "Self" kind (instanceBindings found)
    (Nothing, kind : _) | instanceSelfAtCall found -> Map.insert "Self" kind (instanceBindings found)
    _ -> instanceBindings found))
  -- The owner a type parameter stands for settles its implementation's own
  -- parameters: `A` of `impl [A] Named for Array[A]` where `T` is Array[Int].
  owned found = case selectedOwner selected of
    Nothing -> Map.empty
    Just kind -> Map.fromList
      [ (name, formed)
      | ((trait, owner), implemented) <- Map.toList (contextHeads context)
      , (owner <> "." <> trait <> ".") `Text.isPrefixOf` key
      , Just matched <- [matchType (headTarget implemented) (unformed kind) Map.empty]
      , (name, held) <- Map.toList matched
      , name `elem` map fst (schemeParams (instanceScheme found))
      , Just formed <- [formedCoreTypeIn (contextTypes context) held] ]
  -- Written type arguments fill the parameters still open, in order.
  written found = Map.fromList (zip
    [name | (name, _) <- schemeParams (instanceScheme found), name /= "Self", Map.notMember name (instanceBindings found)]
    (selectedArguments selected))
  -- A static call checking recorded no fact for takes its copy's own type,
  -- which the bindings in hand then fill.
  schemeInstantiation found
    | Map.null (owned found) && Map.null (written found) && selectedOwner selected == Nothing = Nothing
    | otherwise = Just (schemeType (instanceScheme found))

{-| A call whose instance has loaned parameters, lowered from the state
    before the ordinary attempt: the operands run in the order given. -}
loanedInstanceCall
  :: LowerExpression -> LowerState -> Span -> Text -> Maybe Type -> [CoreType] -> Selected
  -> [(Int, Operand, Located Expression)] -> Maybe Lowered
loanedInstanceCall lower state at key instantiated receiver selected operands =
  case instanceTarget state at key instantiated receiver selected of
    (admitted, Just (target, signature))
      | not (null (signatureLoaned signature)) ->
          Just (lowerLoanedOperands lower admitted at (Direct target) signature (takesSuppliedCount signature) operands)
    _ -> Nothing

{-| A call to a method instance with lowered operands, receiver first. -}
callInstance :: LowerState -> Span -> Text -> Maybe Type -> [CoreExpression] -> Lowered
callInstance state at key instantiated = invoke state at key instantiated unselected

lowerAll :: LowerExpression -> LowerState -> [Located Expression] -> (LowerState, Maybe [CoreExpression])
lowerAll lower = go []
 where
  go collected current [] = (current, Just (reverse collected))
  go collected current (argument : rest) = case lower current argument of
    (after, Just (core, _))
      | coreExpressionType core == CoreNeverType -> (after, Just (reverse (core : collected)))
      | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] call argument" after
      | otherwise -> go (core : collected) after rest
    (after, Nothing) -> (after, Nothing)
