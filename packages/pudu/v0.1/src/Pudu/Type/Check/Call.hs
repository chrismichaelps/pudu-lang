{-| @Type.Check.Call — resolves what a call's callee refers to -}
module Pudu.Type.Check.Call
  ( CheckExpression (..)
  , checkCallee
  , selectedStaticCallee
  , checkCalleeLending
  , throughBorrow
  , traitQualifiedCall
  ) where

import Control.Monad (when)
import qualified Data.List.NonEmpty as NonEmpty
import Pudu.Type.Check.Place (checkExclusiveReceiver, exclusiveInput)
import Pudu.Type.Check.Receiver (bindReceiver)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Maybe (mapMaybe)
import Pudu.Type.Formation (formType)
import Pudu.Type.Implementation (ImplementationRule (..), selectImplementationTarget)
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Expression (..), TypeSyntax (NamedType)
  )
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker
  , DeclaredTypes (..)
  , ambiguousProviders
  , recordSelection
  , freshVariable
  , lookupImplementations
  , methodProvider
  , lookupName
  , recordExpression
  , report
  )
import Pudu.Type.Check.Rule
  ( instantiateWith
  , instantiate
  , memberType
  , namedVariantAsValue
  , qualifiedMemberType
  )
import Pudu.Type.Check.Method
  ( methodScheme
  , traitMethodScheme
  , targetName
  )
import Pudu.Type.Unify (zonk)
import Pudu.Type.Value
  ( NominalId (..)
  , Scheme (..)
  , nominalKey
  , Type (..)
  )

{-| @Check.Call.CheckExpression — checking an expression.

    A call's arguments are expressions and an expression may be a call, so one
    of the two directions has to be an argument rather than an import. This is
    that direction, the same shape the parser uses for its own recursion. -}
newtype CheckExpression = CheckExpression
  { runCheck :: DeclaredTypes -> [(Text, Int)] -> Located Expression -> Checker Type
  }

{-| A member in callee position prefers a method over a field of the same
    name, because `value.name()` reads as a call and a field would have to be
    parenthesized to be called anyway. -}
checkCallee :: CheckExpression -> DeclaredTypes -> [(Text, Int)] -> Located Expression -> Checker Type
checkCallee checker declared rigid located = fst <$> checkCalleeLending checker declared rigid located

{-| The callee's type, and the receiver when the method it names takes
    `self: &mut Self` and so changes the receiver it is called on. -}
checkCalleeLending
  :: CheckExpression
  -> DeclaredTypes
  -> [(Text, Int)]
  -> Located Expression
  -> Checker (Type, Maybe (Located Expression))
checkCalleeLending checker declared rigid located@(Located calleeSpan expression) = case expression of
  MemberExpression target member -> do
    {-| A variant that named its payload is refused before the callee is
        resolved at all, and answered here rather than left to fall through.
        Falling through re-checks the same member as an expression, which
        reports the one mistake twice. -}
    refused <- namedVariantAsValue calleeSpan (locatedValue member)
    case refused of
      Just value -> pure (value, Nothing)
      Nothing -> do
        selected <- selectedStaticCallee declared rigid calleeSpan expression []
        named <- maybe (qualifiedByName declared calleeSpan (locatedValue target) (locatedValue member))
          (pure . Just) selected
        qualified <- case named of
          Just found -> pure (Just found)
          Nothing -> qualifiedMemberType declared calleeSpan (locatedValue target) (locatedValue member)
        case qualified of
          Just instantiated -> do
            recordExpression calleeSpan instantiated
            pure (instantiated, Nothing)
          Nothing -> do
            targetType <- runCheck checker declared rigid target
            resolved <- throughBorrow =<< zonk targetType
            method <- methodScheme calleeSpan resolved (locatedValue member)
            case method of
              {-| Not a method, so a field, typed from the receiver just checked.
                  Checking the member expression again would check the receiver
                  again, and each call in a chain would double the work and the
                  diagnostics of every call before it. -}
              Nothing -> do
                found <- memberType calleeSpan targetType (locatedValue member)
                resolvedMember <- zonk found
                recordExpression calleeSpan resolvedMember
                pure (found, Nothing)
              Just scheme -> do
                instantiated <- instantiate calleeSpan scheme
                changesReceiver <- case instantiated of
                  FunctionTypeValue _ (selfInput : _) _ -> exclusiveInput selfInput
                  _ -> pure False
                applied <- bindReceiver calleeSpan resolved instantiated
                when changesReceiver (checkExclusiveReceiver target)
                recordExpression calleeSpan applied
                pure (applied, if changesReceiver then Just target else Nothing)
  _ -> (\found -> (found, Nothing)) <$> runCheck checker declared rigid located

{-| A complete nominal owner selects implementation parameters by its head,
    before method-local arguments instantiate the ordinary method scheme. -}
selectedStaticCallee :: DeclaredTypes -> [(Text, Int)] -> Span -> Expression -> [Type] -> Checker (Maybe Type)
selectedStaticCallee declared rigid at expression written = case expression of
  MemberExpression (Located ownerAt (TypeApplication owner arguments)) member
    | Just path <- nominalPath (locatedValue owner) -> do
        selected <- formType declared rigid (Located ownerAt (NamedType (ModuleName path) arguments))
        case selected of
          NominalType identity _ -> do
            scheme <- methodScheme at selected (locatedValue member)
            provider <- methodProvider (nominalKey identity <> "." <> locatedValue member)
            case (scheme, provider) of
              (Just Scheme{schemeType = ErrorType}, _) -> pure (Just ErrorType)
              (Just found, Just trait) -> do
                rules <- lookupImplementations identity trait
                let matching = mapMaybe (\rule -> (rule,) <$> selectImplementationTarget selected rule) rules
                case matching of
                  (rule, bindings) : rest | all ((== rule) . fst) rest -> do
                    prefix <- mapM (\(name, _) -> maybe freshVariable pure (lookup name bindings))
                      (implementationParameters rule)
                    remaining <- mapM (const freshVariable)
                      (drop (length prefix + length written) (schemeParams found))
                    let chosen = prefix <> written <> remaining
                    recordSelection at chosen
                    Just <$> instantiateWith at found chosen
                  _ -> refusal "E3013" "the static owner has no unique implementation selection"
              (Just found, Nothing) -> Just <$> instantiateWith at found written
              _ -> refusal "E3005" "the static owner has no such method"
          _ -> refusal "E3028" "a static owner must be a nominal type"
  _ -> pure Nothing
 where
  refusal code message = report code at message Nothing >> pure (Just ErrorType)
  nominalPath value = case value of
    NameExpression path -> Just path
    MemberExpression target member -> (<> NonEmpty.singleton (locatedValue member)) <$> nominalPath (locatedValue target)
    _ -> Nothing

{-| A callee written as `Name.member` may select a method by the trait that
    declares it or by the type that implements it. The written name is mapped to
    the declaration it identifies before the method key is built, so a local
    declaration and an imported one are reached the same way. -}
qualifiedByName
  :: DeclaredTypes -> Span -> Expression -> Text -> Checker (Maybe Type)
qualifiedByName declared spanValue target member = case target of
  NameExpression (first NonEmpty.:| []) -> case Map.lookup first (declaredNames declared) of
    Nothing -> pure Nothing
    Just identity -> do
      -- A module qualifier that exports `member` names that value, even where
      -- the module also has a type of the qualifier's spelling: `Json.encode`
      -- is the module's function, not the `Json` type's method.
      exported <- if Set.member first (declaredQualifiers declared)
        then lookupName (first <> "." <> member)
        else pure Nothing
      case exported of
        Just _ -> pure Nothing
        Nothing -> byType identity
  _ -> pure Nothing
 where
  byType identity = do
    let key = nominalKey identity <> "." <> member
    providers <- ambiguousProviders key
    case providers of
      _ : _ -> do
        report "E3013" spanValue
          (member <> " is ambiguous for " <> nominalName identity)
          ( Just
              ( "name the trait instead: "
                  <> Text.intercalate " or "
                    [nominalName provider <> "." <> member <> "(value)" | provider <- providers]
              )
          )
        pure (Just ErrorType)
      [] -> do
        found <- lookupName key
        case found of
          Nothing -> pure Nothing
          Just scheme -> Just <$> instantiate spanValue scheme

{-| Resolve a trait-qualified call against the type its receiver actually has.

    `Speak.label(&bot)` names the trait, but the method it runs is the one `Bot`
    implements, and only that one knows the concrete types. The trait's own
    declaration cannot: a generic trait leaves its parameters open there by
    design, so typing the call from the declaration gave back the parameter
    itself and every use was a mismatch against it.

    This is the rule [[Evaluator]] already followed for the same call, so the
    two phases now agree about what a trait-qualified call means rather than
    only appearing to.

    The receiver is checked once, here, and its type handed back so the call is
    not walked twice. -}
traitQualifiedCall
  :: CheckExpression
  -> DeclaredTypes
  -> [(Text, Int)]
  -> Located Expression
  -> [Located Expression]
  -> Checker (Maybe (Type, [Type]))
traitQualifiedCall checker declared rigid (Located calleeSpan callee) arguments = case (callee, arguments) of
  (MemberExpression target member, receiver : rest)
    | Just traitIdentity <- namedType (locatedValue target)
    , Set.member traitIdentity (declaredTraitNames declared) -> do
      declaredMember <- lookupName (nominalKey traitIdentity <> "." <> locatedValue member)
      -- Only a member taking `self` has a receiver to dispatch on; a static
      -- member's first argument is ordinary data, so its owner is inferred.
      if not (maybe False (takesSelf . schemeType) declaredMember) then pure Nothing else do
          receiverType <- runCheck checker declared rigid receiver
          resolved <- throughBorrow =<< zonk receiverType
          case targetName resolved of
            Nothing -> do
              found <- traitMethodScheme calleeSpan resolved traitIdentity (locatedValue member)
              case found of
                Nothing -> pure Nothing
                Just scheme -> do
                  instantiated <- instantiate calleeSpan scheme
                  recordExpression calleeSpan instantiated
                  restTypes <- mapM (runCheck checker declared rigid) rest
                  pure (Just (instantiated, receiverType : restTypes))
            Just owner -> do
              found <- lookupName (nominalKey owner <> "." <> locatedValue member)
              case found of
                Nothing -> pure Nothing
                Just scheme
                  | nominalKey owner == nominalKey traitIdentity -> pure Nothing
                  | otherwise -> do
                      instantiated <- instantiate calleeSpan scheme
                      recordExpression calleeSpan instantiated
                      restTypes <- mapM (runCheck checker declared rigid) rest
                      pure (Just (instantiated, receiverType : restTypes))
  _ -> pure Nothing
 where
  namedType expression = case expression of
    NameExpression (first NonEmpty.:| []) -> Map.lookup first (declaredNames declared)
    _ -> Nothing
  takesSelf held = case held of
    FunctionTypeValue _ (first : _) _ -> isSelf first
    _ -> False
  isSelf held = case held of
    RigidType "Self" -> True
    ReferenceTypeValue _ inner -> isSelf inner
    _ -> False

{-| The type a borrow refers to, following as many references as were written.

    A `&&T` is unusual but writable, and stopping after one would report a
    confusing mismatch against a type the reader never intended to match on. -}
throughBorrow :: Type -> Checker Type
throughBorrow typeValue = do
  resolved <- zonk typeValue
  case resolved of
    ReferenceTypeValue _ referent -> throughBorrow referent
    _ -> pure resolved
