{-| @Pudu.Compiler.Lower.Generic — one copy of a generic body per type-argument
    list, read off the instantiation checking recorded at the call. -}
module Pudu.Compiler.Lower.Generic (admitCallee, specialize) where

import Control.Monad (foldM)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Signature (ensureSignature)
import Pudu.Compiler.Lower.State
  ( CoreSignature, Instance (..), LowerContext (..), LowerState (..), halt, inModule, withTypeBindings )
import Pudu.Compiler.Lower.Types (formedCoreTypeIn, lookupScheme, typeBindings, typeFactAt)
import qualified Data.List.NonEmpty as NonEmpty
import Pudu.Core (CoreType (..), coreTypeName)
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax (Function (..), Located (..))
import Pudu.Source (Span)
import Pudu.Type.Value (NominalId (..), Scheme (..), Type (..))

{-| Admit a call's callee and answer the key the call names: the function
    itself when it is monomorphic, otherwise its copy for the types checking
    instantiated it at `callee`. The signature is admitted in the callee's
    module under the callee's bindings; the caller's come back afterwards. -}
admitCallee :: LowerState -> Text -> Span -> (Text, Located Function) -> (LowerState, Maybe (Text, CoreSignature))
admitCallee state key callee (owner, function) = case scheme of
  Just found
    | not (null (schemeParams found)) -> case typeFactAt (contextTypes context) callee >>= specialize state key owner function found Map.empty of
        Just (registered, instanceKey, bindings) -> admit registered instanceKey bindings
        Nothing -> halt callee "a generic call whose type arguments have no native representation" state
  _ -> admit state key Map.empty
 where
  context = lowerContext state
  scheme = lookupScheme (contextTypes (lowerContext (inModule owner state))) (locatedValue (functionName (locatedValue function)))
  admit current target bindings =
    let (admitted, signature) = ensureSignature target function (withTypeBindings bindings (inModule owner current))
        back = withTypeBindings (typeBindings (contextTypes context)) (inModule (contextModule context) admitted)
     in (back, (,) target <$> signature)

{-| Bind a scheme's rigid parameters against an instantiation and register the
    copy. `fixed` is what is already known (`Self` for an inherited default).
    A parameter the instantiation leaves open names nothing any value holds,
    so unit stands for it. Every binding is formed in the caller's facts, so a
    caller that is itself a copy passes its own bindings through. -}
specialize
  :: LowerState -> Text -> Text -> Located Function -> Scheme -> Map Text CoreType -> Type
  -> Maybe (LowerState, Text, Map Text CoreType)
specialize state key owner function scheme fixed actual = do
  matched <- matchType (schemeType scheme) (substitute (typeBindings (contextTypes context)) actual) Map.empty
  formed <- traverse (form matched) [name | (name, _) <- schemeParams scheme, Map.notMember name fixed]
  let bindings = Map.union fixed (Map.fromList formed)
      instanceKey = key <> "[" <> Text.intercalate "," [Text.pack (show kind) | kind <- Map.elems bindings] <> "]"
      known = Instance owner function scheme bindings False
      registered = state{lowerContext = context{contextInstances = Map.insert instanceKey known (contextInstances context)}}
  pure (registered, instanceKey, bindings)
 where
  context = lowerContext state
  form matched name = case Map.lookup name matched of
    Nothing -> Just (name, CoreUnitType)
    Just (VariableType _) -> Just (name, CoreUnitType)
    Just held -> (,) name <$> formedCoreTypeIn (contextTypes context) held

{-| Inside a copy, facts still name its own rigid parameters; put back what
    they stand for there, so a call made from the copy specializes too. -}
substitute :: Map Text CoreType -> Type -> Type
substitute bindings value = case value of
  RigidType name | Just bound <- Map.lookup name bindings -> unformed bound
  NominalType identity arguments -> NominalType identity (map (substitute bindings) arguments)
  TupleTypeValue members -> TupleTypeValue (map (substitute bindings) members)
  ReferenceTypeValue mutable inner -> ReferenceTypeValue mutable (substitute bindings inner)
  FunctionTypeRequiring asynchronous inputs required result ->
    FunctionTypeRequiring asynchronous (map (substitute bindings) inputs) required (substitute bindings result)
  _ -> value

{-| The checker's spelling of a formed type: the identity `nominalKey` was
    made from, builtins by their own name. -}
unformed :: CoreType -> Type
unformed kind = case kind of
  CoreRecordType key arguments -> NominalType (identityOf key) (map unformed arguments)
  CoreSumType key arguments -> NominalType (identityOf key) (map unformed arguments)
  CoreTupleType members -> TupleTypeValue (map unformed members)
  CoreUnitType -> UnitTypeValue
  CoreNeverType -> NeverType
  other -> NominalType (NominalId Nothing (coreTypeName other)) []
 where
  identityOf key = case NonEmpty.nonEmpty (Text.splitOn "." key) of
    Just segments | length segments > 1 ->
      NominalId (Just (ModuleName (NonEmpty.fromList (NonEmpty.init segments)))) (NonEmpty.last segments)
    _ -> NominalId Nothing key

{-| The rigid parameters of `pattern` as `actual` fills them. A shared
    reference on one side only is looked through: a receiver is passed by
    value where the member was written `self: &Self`. -}
matchType :: Type -> Type -> Map Text Type -> Maybe (Map Text Type)
matchType pattern actual bound = case (pattern, actual) of
  (RigidType name, _) -> case Map.lookup name bound of
    Nothing -> Just (Map.insert name actual bound)
    Just earlier
      | earlier == actual -> Just bound
      | otherwise -> Nothing
  (ReferenceTypeValue mutable inner, ReferenceTypeValue other held)
    | mutable == other -> matchType inner held bound
  (ReferenceTypeValue False inner, _) -> matchType inner actual bound
  (_, ReferenceTypeValue False held) -> matchType pattern held bound
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
