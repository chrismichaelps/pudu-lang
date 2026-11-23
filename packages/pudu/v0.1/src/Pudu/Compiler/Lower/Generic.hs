{-| @Pudu.Compiler.Lower.Generic — one copy of a generic body per type-argument
    list, read off the instantiation checking recorded at the call. -}
module Pudu.Compiler.Lower.Generic (admitCallee, admitCalleeGiven, runtimeCallSignature, matchType, specialize, substitute, instantiationOf, unformed, writtenCoreType, writtenTypeArguments) where

import Control.Monad (foldM)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Default (takesSuppliedCount)
import Pudu.Compiler.Lower.Signature (ensureSignature, taskSignatureResult)
import Pudu.Compiler.Lower.Dynamic (hasRuntimeChoice, runtimeCarriers, runtimeResultType, settledMutableLayout, writtenType)
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), Head (..), Instance (..), LowerContext (..), LowerState (..), MutableSite (MutableParameterSite)
  , halt, inModule, isModuleQualifier, lookupLocal, resolveFunction, withTypeBindings )
import Pudu.Compiler.Lower.Types (formedCoreTypeIn, lookupScheme, typeBindings, typeFactAt, unformed)
import qualified Data.List.NonEmpty as NonEmpty
import Pudu.Core (CoreLocal (..), CoreParameter (..), CoreType (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax (Expression (..), Function (..), Located (..), TypeSyntax (..))
import Pudu.Source (Span, typeArgumentsKey)
import Pudu.Type.Value (NominalId (..), Scheme (..), Type (..), TypeVar (..), nominalKey)
import Pudu.Type.Substitute (substituteRigid)

{-| Register a native copy with the layouts its caller supplies. -}
runtimeCallSignature :: (Text, Located Function) -> LowerState -> Text -> CoreSignature -> [CoreType]
  -> Maybe (LowerState, Text, CoreSignature)
runtimeCallSignature (owner, function) current target signature given = do
  let context = lowerContext current
      expected = map (coreLocalType . coreParameterLocal) (signatureParameters signature)
      pairs = zip expected given
  if any (uncurry differs) pairs
    && all (\(wanted, actual) -> wanted == actual || hasRuntimeChoice actual) pairs
    then do
      instance' <- case Map.lookup target (contextInstances context) of
        Just existing -> Just existing
        Nothing -> do
          let types = contextTypes (lowerContext (inModule owner current))
          scheme <- lookupScheme types (locatedValue (functionName (locatedValue function)))
          pure (Instance owner function scheme Map.empty False Map.empty)
      let settledInputs = zipWith3 input [0 ..] expected given <> drop (length given) expected
          input position wanted actual
            | wanted == actual = wanted
            | takesSuppliedCount signature, position `notElem` signatureLoaned signature =
                runtimeResultType wanted (runtimeCarriers wanted <> runtimeCarriers actual)
            | otherwise = actual
          name = fst (Text.breakOn "$runtime" target) <> "$runtime" <> Text.pack (show settledInputs)
          result
            | functionAsync (locatedValue function) =
                taskSignatureResult context name (locatedValue function) (signatureResult signature)
            | otherwise = runtimeResultType (signatureResult signature)
                (Map.findWithDefault Set.empty name (contextRuntimeResults context))
          parameters = zipWith3 parameterWith [0 ..] settledInputs (signatureParameters signature)
          parameterWith position kind parameter =
            let local = coreParameterLocal parameter
                actual
                  | position `elem` signatureLoaned signature =
                      settledMutableLayout context (MutableParameterSite name position) kind
                  | otherwise = kind
             in parameter{coreParameterLocal = local{coreLocalType = actual}}
          exact = signature{signatureParameters = parameters, signatureResult = result}
          registered = current{lowerContext = context
            { contextInstances = Map.insert name instance' (contextInstances context)
            , contextSignatures = Map.insert name (Just exact) (contextSignatures context) }}
      Just (registered, name, exact)
    else Nothing
 where
  differs wanted actual = wanted /= actual && hasRuntimeChoice actual

{-| Admit a call's callee and answer the key the call names: the function
    itself when it is monomorphic, otherwise its copy for the types checking
    instantiated it at `callee`. The signature is admitted in the callee's
    module under the callee's bindings; the caller's come back afterwards. -}
admitCallee :: LowerState -> Text -> Span -> (Text, Located Function) -> (LowerState, Maybe (Text, CoreSignature))
admitCallee state = admitCalleeGiven state Nothing

{-| The same, with the arguments' own types where checking recorded them.
    A call through a constructor parameter leaves the callee's fact naming
    an application it never settled; the arguments say what was applied. -}
admitCalleeGiven :: LowerState -> Maybe [Type] -> Text -> Span -> (Text, Located Function) -> (LowerState, Maybe (Text, CoreSignature))
admitCalleeGiven state operands key callee entry@(owner, function)
  | key == contextEntry context = case entryCopy state key entry of
      Just (registered, copyKey) -> admitCalleeGiven registered operands copyKey callee entry
      Nothing -> halt callee "a call to the entry function without a solved signature" state
  | otherwise = case scheme of
      Just found
        | not (null (schemeParams found)) -> case instantiation >>= specialize taken key owner function found (written found) Map.empty of
            Just (registered, instanceKey, bindings) -> admit registered instanceKey bindings
            Nothing -> halt callee "a generic call whose type arguments have no native representation" taken
      _ -> admit taken key Map.empty
 where
  context = lowerContext state
  instantiation = case (typeFactAt (contextTypes context) callee, operands) of
    (Just fact@(FunctionTypeRequiring asynchronous inputs required result), Just given)
      | unsettled fact, length given == length inputs ->
          Just (FunctionTypeRequiring asynchronous given required (if unsettled result then VariableType (TypeVar 0) else result))
    (fact, _) -> fact
  unsettled value = case value of
    AppliedType (VariableType _) _ -> True
    AppliedType applied arguments -> any unsettled (applied : arguments)
    NominalType _ arguments -> any unsettled arguments
    TupleTypeValue members -> any unsettled members
    ReferenceTypeValue _ inner -> unsettled inner
    FunctionTypeRequiring _ inputs _ result -> any unsettled (result : inputs)
    _ -> False
  taken = state{lowerTypeArguments = []}
  -- Written type arguments fill the parameters in the order declared.
  written found
    | length (lowerTypeArguments state) == length (schemeParams found) =
        Map.fromList (zip (map fst (schemeParams found)) (lowerTypeArguments state))
    | otherwise = Map.empty
  scheme = lookupScheme (contextTypes (lowerContext (inModule owner state))) (locatedValue (functionName (locatedValue function)))
  admit current target bindings =
    let (admitted, signature) = ensureSignature target function (withTypeBindings bindings (inModule owner current))
        back = withTypeBindings (typeBindings (contextTypes context)) (inModule (contextModule context) admitted)
     in (back, (,) target <$> signature)

{-| The entry called from the program: an ordinary copy of the entry body,
    taking its arguments and answering its value, since the entry itself
    reports through the exit status and standard output. -}
entryCopy :: LowerState -> Text -> (Text, Located Function) -> Maybe (LowerState, Text)
entryCopy state key (owner, function) = do
  scheme <- lookupScheme (contextTypes (lowerContext (inModule owner state))) (locatedValue (functionName (locatedValue function)))
  let copyKey = key <> "[]"
      known = Instance owner function scheme Map.empty False Map.empty
      context = lowerContext state
  pure (state{lowerContext = context{contextInstances = Map.insert copyKey known (contextInstances context)}}, copyKey)

{-| Bind a scheme's rigid parameters against an instantiation and register the
    copy. `fixed` is what is already known (`Self` for an inherited default).
    A parameter the instantiation leaves open names nothing any value holds,
    so unit stands for it. Every binding is formed in the caller's facts, so a
    caller that is itself a copy passes its own bindings through. -}
specialize
  :: LowerState -> Text -> Text -> Located Function -> Scheme -> Map Text CoreType -> Map Text Type -> Type
  -> Maybe (LowerState, Text, Map Text CoreType)
specialize state key owner function scheme fixed derived actual = do
  direct <- matchType (schemeType scheme) (substitute (typeBindings (contextTypes context)) actual) Map.empty
  let matched = throughBounds (contextHeads context) 8 (schemeBounds scheme) direct
  formed <- traverse (form matched) [name | (name, _) <- schemeParams scheme, Map.notMember name fixed]
  let own = Map.union fixed (Map.fromList formed)
      replacements = Map.toList (Map.union matched (Map.map unformed fixed))
  settled <- traverse (formedCoreTypeIn (contextTypes context) . substituteRigid replacements) derived
  let bindings = Map.union settled own
      instanceKey = key <> "[" <> Text.intercalate "," [Text.pack (show kind) | kind <- Map.elems bindings] <> "]"
      known = Instance owner function scheme{schemeType = substituteRigid replacements (schemeType scheme)} bindings False Map.empty
      registered = state{lowerContext = context{contextInstances = Map.insert instanceKey known (contextInstances context)}}
  pure (registered, instanceKey, bindings)
 where
  context = lowerContext state
  form matched name = case Map.lookup name matched of
    Nothing -> Just (name, CoreUnitType)
    Just (VariableType _) -> Just (name, CoreUnitType)
    -- A parameter standing for a constructor is bound to the constructor
    -- and the arguments it already has, named as a record of that key.
    Just (NominalType identity prefix) | maybe False (> 0) (lookup name (schemeParams scheme)) ->
      (,) name . CoreRecordType (nominalKey identity) <$> traverse (formedCoreTypeIn (contextTypes context)) prefix
    Just held -> (,) name <$> formedCoreTypeIn (contextTypes context) held

{-| Settle the parameters only a bound names. Where a parameter is already
    a nominal type, the head providing each of its bounds for that type says
    what the bound's arguments are; matching them settles more parameters,
    which may settle others in turn. The fuel bounds heads that lead back to
    themselves. -}
throughBounds :: Map (Text, Text) Head -> Int -> [(Text, [Type])] -> Map Text Type -> Map Text Type
throughBounds heads fuel bounds matched
  | fuel <= 0 || extended == matched = matched
  | otherwise = throughBounds heads (fuel - 1) bounds extended
 where
  extended = foldl' step matched
    [ (written, provided)
    | (parameter, traits) <- bounds
    , Just concrete@(NominalType owner _) <- [Map.lookup parameter matched]
    , NominalType trait written <- traits
    , Just found <- [Map.lookup (nominalName trait, nominalKey owner) heads]
    , Just own <- [matchType (headTarget found) concrete Map.empty]
    , let settled = Map.toList (throughBounds heads (fuel - 1) (headBounds found) own)
          provided = map (substituteRigid settled) (headArguments found)
    , length written == length provided ]
  step current (written, provided) =
    maybe current id (foldM (\bound (left, right) -> matchType left right bound) current (zip written provided))

{-| The instantiation a call makes when checking recorded none for it, as a
    `for` asking a sequence for `begin` does: the operands' own types fill
    the scheme's inputs, and the result is whatever they leave it. -}
instantiationOf :: Scheme -> [CoreType] -> Maybe Type
instantiationOf scheme operands = case schemeType scheme of
  FunctionTypeRequiring asynchronous inputs required _
    | length inputs == length operands ->
        Just (FunctionTypeRequiring asynchronous (map unformed operands) required (VariableType (TypeVar 0)))
  _ -> Nothing

{-| Inside a copy, facts still name its own rigid parameters; put back what
    they stand for there, so a call made from the copy specializes too. -}
substitute :: Map Text CoreType -> Type -> Type
substitute bindings value = case value of
  RigidType name | Just bound <- Map.lookup name bindings -> unformed bound
  NominalType identity arguments -> NominalType identity (map (substitute bindings) arguments)
  AppliedType applied arguments -> case substitute bindings applied of
    NominalType identity prefix -> NominalType identity (prefix <> map (substitute bindings) arguments)
    other -> AppliedType other (map (substitute bindings) arguments)
  TupleTypeValue members -> TupleTypeValue (map (substitute bindings) members)
  ReferenceTypeValue mutable inner -> ReferenceTypeValue mutable (substitute bindings inner)
  FunctionTypeRequiring asynchronous inputs required result ->
    FunctionTypeRequiring asynchronous (map (substitute bindings) inputs) required (substitute bindings result)
  RestrictedType constraints target -> RestrictedType constraints (substitute bindings target)
  _ -> value

{-| The rigid parameters of `pattern` as `actual` fills them. A shared
    reference on one side only is looked through: a receiver is passed by
    value where the member was written `self: &Self`. -}
matchType :: Type -> Type -> Map Text Type -> Maybe (Map Text Type)
matchType pattern actual bound = case (pattern, actual) of
  (RigidType name, _) -> case Map.lookup name bound of
    Nothing -> Just (Map.insert name actual bound)
    Just earlier
      | earlier == actual -> Just bound
      -- A type left open says nothing against one already settled.
      | VariableType _ <- actual -> Just bound
      | VariableType _ <- earlier -> Just (Map.insert name actual bound)
      | otherwise -> Nothing
  -- A constructor parameter applied: it stands for the actual type's
  -- constructor with the arguments the application does not supply.
  (AppliedType (RigidType name) arguments, NominalType identity held)
    | length held >= length arguments ->
        let (prefix, supplied) = splitAt (length held - length arguments) held
            constructor = NominalType identity prefix
         in case Map.lookup name bound of
              Just earlier | earlier /= constructor -> Nothing
              _ -> foldM (\current (left, right) -> matchType left right current) (Map.insert name constructor bound) (zip arguments supplied)
  (ReferenceTypeValue mutable inner, ReferenceTypeValue other held)
    | mutable == other -> matchType inner held bound
  -- A reference of either kind holds its target natively, so a receiver
  -- lent to `self: &mut Self` matches as the value it is.
  (ReferenceTypeValue _ inner, _) -> matchType inner actual bound
  (_, ReferenceTypeValue _ held) -> matchType pattern held bound
  (NominalType identity arguments, NominalType other held)
    | identity == other, length arguments == length held -> pairs (zip arguments held)
  (TupleTypeValue members, TupleTypeValue held)
    | length members == length held -> pairs (zip members held)
  (FunctionTypeRequiring _ inputs _ result, FunctionTypeRequiring _ held _ answer)
    | length inputs == length held -> pairs ((result, answer) : zip inputs held)
  (_, VariableType _) -> Just bound
  _
    | pattern == actual -> Just bound
    | otherwise -> Nothing
 where
  pairs = foldM (\current (left, right) -> matchType left right current) bound

{-| A type as a call wrote it, where checking recorded no fact for it: a
    parameter of the copy being lowered, a builtin, or a record or sum by the
    canonical path elaboration writes, else by its name in this module. -}
writtenCoreType :: LowerState -> Located TypeSyntax -> Maybe CoreType
writtenCoreType state (Located at written) = case written of
  NamedType (ModuleName path) []
    | Just bound <- Map.lookup (pathText path) (typeBindings types) -> Just bound
  NamedType (ModuleName path) arguments -> do
    formed <- traverse (writtenCoreType state) arguments
    let name = pathText path
        qualified = case NonEmpty.nonEmpty (Text.splitOn "." name) of
          Just segments | length segments > 1 ->
            [NominalId (Just (ModuleName (NonEmpty.fromList (NonEmpty.init segments)))) (NonEmpty.last segments)]
          _ -> [NominalId Nothing name, NominalId (Just (ModuleName (NonEmpty.fromList (Text.splitOn "." (contextModule context))))) name]
    case [kind | identity <- qualified, Just kind <- [formedCoreTypeIn types (NominalType identity (map unformed formed))]] of
      kind : _ -> Just kind
      [] -> Nothing
  DynamicType (ModuleName path) ->
    case [kind | name <- [pathText path, contextModule context <> "." <> pathText path]
               , Just kind <- [writtenType [] (Located at (DynamicType (ModuleName (NonEmpty.fromList (Text.splitOn "." name))))) >>= formedCoreTypeIn types]] of
      kind : _ -> Just kind
      [] -> Nothing
  TupleType members -> CoreTupleType <$> traverse (writtenCoreType state) members
  ReferenceType False held -> writtenCoreType state held
  UnitType -> Just CoreUnitType
  _ -> Nothing
 where
  context = lowerContext state
  types = contextTypes context
  pathText = Text.intercalate "." . NonEmpty.toList

{-| The types written on a call to a module's function, held for the
    admission of that callee: `made[Point]()` names a parameter the
    function's own type never mentions. -}
writtenTypeArguments :: LowerState -> Span -> Located Expression -> [Located TypeSyntax] -> LowerState
writtenTypeArguments state application inner written = case locatedValue inner of
  NameExpression (first :| rest)
    | Nothing <- lookupLocal state first, Just _ <- resolveFunction state (first : rest) -> held
  MemberExpression (Located _ (NameExpression (owner :| []))) (Located _ member)
    | isModuleQualifier state owner, Just _ <- resolveFunction state [owner, member] -> held
    -- `Array.parse[Int](text)`: the owner names a type, whose method reads them.
    | Nothing <- lookupLocal state owner -> held
  MemberExpression (Located _ (NameExpression (first :| _ : _))) _
    | Nothing <- lookupLocal state first -> held
  _ -> state
 where
  types = contextTypes (lowerContext state)
  -- Checking records what a program wrote; elaboration writes the rest.
  held = case typeFactAt types (typeArgumentsKey application) of
    Just (TupleTypeValue recorded) | Just formed <- traverse (formedCoreTypeIn types) recorded ->
      state{lowerTypeArguments = formed}
    _ | Just formed <- traverse (writtenCoreType state) written -> state{lowerTypeArguments = formed}
    _ -> state
