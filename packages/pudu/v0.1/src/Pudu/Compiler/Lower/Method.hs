{-| @Pudu.Compiler.Lower.Method — implementation members and trait defaults
    as ordinary native calls, selected by the receiver's checked type. -}
module Pudu.Compiler.Lower.Method (methodTables, lowerMethodCall, lowerQualifiedMethod, callInstance) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.Scalar (eagerType)
import Pudu.Compiler.Lower.Signature (ensureSignature)
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), Instance (..), LowerContext (..), LowerState (..), ModuleScope (..)
  , bindLocal, halt, inModule, refused, withTypeBindings )
import Pudu.Compiler.Lower.Generic (specialize)
import Pudu.Compiler.Lower.Types (formedCoreTypeIn, ownerKeyOf, typeBindings, typeFactAt, typeForSpan, nativeValueType)
import Pudu.Core
import Pudu.Eval.Operator.Access (arrayMethods, mapMethods, setMethods, stringMethods)
import Pudu.Frontend.Syntax
  ( Declaration (..), Expression, Function (..), Impl (..), Located (..), Module (..), Trait (..), TypeSyntax (..) )
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Source (Span)
import Pudu.Type.Value (NominalId, Scheme (..), Type (FunctionTypeRequiring, NominalType), nominalKey)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| Every method checking declared, as an instance keyed by owner, trait and
    member, with the indexes a call reaches it through. A member is found by
    the span of its name: an implementation's own function, or the trait
    member it inherits, which then runs with `Self` bound to the owner.
    A generic implementation's members, and the defaults a generic owner
    inherits, are specialized at each call. -}
methodTables
  :: Map Text ModuleScope
  -> [(Text, Module, [(NominalId, Text, Scheme, Span)])]
  -> (Map Text Instance, Map (Text, Text) Text, Map (Text, Text, Text) Text)
methodTables scopes modules = (Map.fromList instances, Map.fromList calls, Map.fromList qualified)
 where
  entries =
    [ (key, Instance moduleName function scheme bindings (inherited && Map.null bindings), (ownerKey, name), (traitText, ownerKey, name))
    | (moduleName, syntax, methods) <- modules
    , (owner, name, scheme, at) <- methods
    , Just (traitText, function, inherited) <- [declaredAt (moduleDeclarations syntax) at]
    , let ownerKey = nominalKey owner
          key = ownerKey <> "." <> traitText <> "." <> name
          self = Map.lookup moduleName scopes >>= \scope -> formedCoreTypeIn (scopeTypes scope) (NominalType owner [])
    , let bindings = maybe Map.empty (Map.singleton "Self") self
    ]
  instances = [(key, found) | (key, found, _, _) <- entries]
  calls = [(call, key) | (key, _, call, _) <- entries]
  qualified = [(selection, key) | (key, _, _, selection) <- entries]

  declaredAt declarations at = case
    [ (lastSegment (implTrait impl), function, False)
    | Located _ (ImplDeclaration impl) <- declarations
    , function <- implFunctions impl, locatedSpan (functionName (locatedValue function)) == at ] <>
    [ (locatedValue (traitName trait), member, True)
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
lowerMethodCall :: LowerExpression -> LowerState -> Span -> Span -> Located Expression -> Text -> [Located Expression] -> Maybe Lowered
lowerMethodCall lower state at callee receiver member arguments = do
  kind <- typeForSpan (contextTypes context) (locatedSpan receiver)
  if builtinFirst kind then Nothing else
    case ownerKeyOf kind >>= \owner -> Map.lookup (owner, member) (contextMethods context) of
      Just key -> Just (callMethod lower state at key instantiated receiver arguments)
      Nothing
        | member == "toText", null arguments -> Just (rendered kind)
        | otherwise -> Nothing
 where
  context = lowerContext state
  -- The callee's fact has the receiver bound already; put it back in front.
  instantiated = do
    FunctionTypeRequiring asynchronous inputs required result <- typeFactAt (contextTypes context) callee
    held <- typeFactAt (contextTypes context) (locatedSpan receiver)
    Just (FunctionTypeRequiring asynchronous (held : inputs) required result)
  builtinFirst kind = case kind of
    CoreTextType -> member `elem` map fst stringMethods
    CoreCharType -> member `elem` ["code", "toText"]
    CoreArrayType _ -> member `elem` map fst arrayMethods
    CoreMapType _ _ -> member `elem` map fst mapMethods
    CoreSetType _ -> member `elem` map fst setMethods
    _ -> False
  rendered kind = case lower state receiver of
    (after, Nothing) -> refused after
    (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
    (after, Just (core, _))
      | expressionIsPrintValued core -> halt at "toText of a Result[(), Str] value" after
      | nativeValueType kind -> (after, Just (CoreExpression at CoreTextType (CoreDisplay core), CoreTextType))
      | otherwise -> halt at ("toText of a " <> coreTypeName kind <> " value") after

{-| `Owner.member(arguments)`: by the type that implements it or the trait
    that declares it. The receiver is an ordinary first argument here, so the
    arguments simply run in order. The trait form picks the implementation
    for the first argument's type, as the evaluator does. -}
lowerQualifiedMethod :: LowerExpression -> LowerState -> Span -> Span -> Text -> Text -> [Located Expression] -> Maybe Lowered
lowerQualifiedMethod lower state at callee owner member arguments = do
  key <- byTrait `orElse` byType
  Just $ case lowerAll lower state arguments of
    (after, Nothing) -> refused after
    (after, Just cores) -> invoke after at key (typeFactAt (contextTypes context) callee) cores
 where
  context = lowerContext state
  receiverKey = case arguments of
    first : _ -> typeForSpan (contextTypes context) (locatedSpan first) >>= ownerKeyOf
    [] -> Nothing
  byTrait = receiverKey >>= \found -> Map.lookup (owner, found, member) (contextTraitMethods context)
  candidates = [key | ((ownerKey, name), key) <- Map.toList (contextMethods context), name == member, displayName ownerKey == owner]
  byType = case [key | Just found <- [receiverKey], ((ownerKey, name), key) <- Map.toList (contextMethods context), name == member, ownerKey == found, displayName ownerKey == owner] of
    key : _ -> Just key
    [] -> case candidates of
      [only] -> Just only
      _ -> Nothing
  orElse (Just found) _ = Just found
  orElse Nothing other = other

{-| The arguments run before the receiver. Each argument is held in a
    temporary so the receiver can still be passed first. -}
callMethod :: LowerExpression -> LowerState -> Span -> Text -> Maybe Type -> Located Expression -> [Located Expression] -> Lowered
callMethod lower state at key instantiated receiver arguments = case lowerAll lower state arguments of
  (after, Nothing) -> refused after
  (after, Just cores) -> case lower after receiver of
    (final, Nothing) -> refused final
    (final, Just (coreReceiver, _))
      | expressionIsPrintValued coreReceiver -> halt (locatedSpan receiver) "a Result[(), Str] method receiver" final
      | any stops (cores <> [coreReceiver]) -> (final, Just (stopped (cores <> [coreReceiver]), CoreNeverType))
      | null cores -> invoke final at key instantiated [coreReceiver]
      | otherwise ->
          let pushed = final{lowerScopes = [] : lowerScopes final}
              (bound, temporaries) = foldl' hold (pushed, []) cores
              popped = bound{lowerScopes = drop 1 (lowerScopes bound)}
              declarations =
                [ CoreStatement (coreExpressionSpan core) (CoreDeclare local core)
                | (local, core) <- zip temporaries cores ]
              temporaryReads = [CoreExpression (coreExpressionSpan core) (coreLocalType local) (CoreReadLocal local) | (local, core) <- zip temporaries cores]
           in case invoke popped at key instantiated (coreReceiver : temporaryReads) of
                (done, Just (call, kind)) ->
                  (done, Just (CoreExpression at kind (CoreBlockValue (CoreBlock declarations (Just call))), kind))
                other -> other
 where
  stops core = coreExpressionType core == CoreNeverType
  -- An empty name cannot be written, so no source name ever finds it.
  hold (current, held) core =
    let (next, local) = bindLocal current "" (coreExpressionType core)
     in (next, held <> [local])
  stopped cores = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock
    [CoreStatement (coreExpressionSpan core) (CoreEvaluate core) | core <- cores] Nothing))

{-| A call to an instance: its signature is admitted in its own module under
    its own bindings, then the caller's are restored. An instance with open
    parameters is specialized first, against the instantiation at the call. -}
invoke :: LowerState -> Span -> Text -> Maybe Type -> [CoreExpression] -> Lowered
invoke state at key instantiated cores = case Map.lookup key (contextInstances context) of
  Nothing -> halt at "this method" state
  Just found
    | open found -> case instantiated >>= specialize state key (instanceModule found) (instanceFunction found) (instanceScheme found) (fixed found) of
        Just (registered, copy, _) -> invoke registered at copy Nothing cores
        Nothing -> halt at "a generic method without settled type arguments" state
  Just found ->
    let entered = withTypeBindings (instanceBindings found) (inModule (instanceModule found) state)
        (admitted, signature) = ensureSignature key (instanceFunction found) entered
        back = withTypeBindings (typeBindings (contextTypes context)) (inModule (contextModule context) admitted)
     in case signature of
          Nothing -> refused back
          Just CoreSignature{signatureParameters, signatureResult}
            | length signatureParameters /= length cores -> halt at "a method called with this many arguments" back
            | otherwise ->
                let queued = back{lowerContext = (lowerContext back){contextQueue = key : contextQueue (lowerContext back)}}
                 in (queued, Just (CoreExpression at (eagerType signatureResult cores) (CoreCall key cores), eagerType signatureResult cores))
 where
  context = lowerContext state
  open found = instanceSelfAtCall found
    || any ((`Map.notMember` instanceBindings found) . fst) (schemeParams (instanceScheme found))
  fixed found = case cores of
    receiver : _ | instanceSelfAtCall found -> Map.insert "Self" (coreExpressionType receiver) (instanceBindings found)
    _ -> instanceBindings found

{-| A call to a method instance with lowered operands, receiver first. -}
callInstance :: LowerState -> Span -> Text -> Maybe Type -> [CoreExpression] -> Lowered
callInstance = invoke

lowerAll :: LowerExpression -> LowerState -> [Located Expression] -> (LowerState, Maybe [CoreExpression])
lowerAll lower = go []
 where
  go collected current [] = (current, Just (reverse collected))
  go collected current (argument : rest) = case lower current argument of
    (after, Just (core, _))
      | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] call argument" after
      | otherwise -> go (core : collected) after rest
    (after, Nothing) -> (after, Nothing)
