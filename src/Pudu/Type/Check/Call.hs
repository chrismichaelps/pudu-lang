{-| @Type.Check.Call — resolves what a call's callee refers to -}
module Pudu.Type.Check.Call
  ( CheckExpression (..)
  , checkCallee
  , throughBorrow
  , traitQualifiedCall
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Expression (..)
  )
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker
  , DeclaredTypes (..)
  , ambiguousProviders
  , lookupName
  , recordExpression
  , report
  )
import Pudu.Type.Check.Rule
  ( awaitType
  , instantiate
  , qualifiedMemberType
  )
import Pudu.Type.Check.Method
  ( declareBounds
  , methodScheme
  , targetName
  )
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value
  ( NominalId (..)
  , nominalKey
  , Type (..)
  )

{-| @Check.Call.CheckExpression — checking an expression.

    A call's arguments are expressions and an expression may be a call, so one
    of the two directions has to be an argument rather than an import. This is
    that direction, the same shape the parser uses for its own recursion. -}
newtype CheckExpression = CheckExpression
  { runCheck :: DeclaredTypes -> [Text] -> Located Expression -> Checker Type
  }

{-| A member in callee position prefers a method over a field of the same
    name, because `value.name()` reads as a call and a field would have to be
    parenthesized to be called anyway. -}
checkCallee :: CheckExpression -> DeclaredTypes -> [Text] -> Located Expression -> Checker Type
checkCallee checker declared rigid located@(Located calleeSpan expression) = case expression of
  MemberExpression target member -> do
    named <- qualifiedByName declared calleeSpan (locatedValue target) (locatedValue member)
    qualified <- case named of
      Just found -> pure (Just found)
      Nothing -> qualifiedMemberType calleeSpan (locatedValue target) (locatedValue member)
    case qualified of
      Just instantiated -> do
        recordExpression calleeSpan instantiated
        pure instantiated
      Nothing -> do
        targetType <- runCheck checker declared rigid target
        resolved <- zonk targetType
        method <- methodScheme calleeSpan resolved (locatedValue member)
        case method of
          Nothing -> runCheck checker declared rigid located
          Just scheme -> do
            instantiated <- instantiate calleeSpan scheme
            let applied = case instantiated of
                  FunctionTypeValue asynchronous (_ : rest) result ->
                    FunctionTypeValue asynchronous rest result
                  other -> other
            recordExpression calleeSpan applied
            pure applied
  _ -> runCheck checker declared rigid located

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
  _ -> pure Nothing

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
  -> [Text]
  -> Located Expression
  -> [Located Expression]
  -> Checker (Maybe (Type, [Type]))
traitQualifiedCall checker declared rigid (Located calleeSpan callee) arguments = case (callee, arguments) of
  (MemberExpression target member, receiver : rest)
    | Just traitIdentity <- namedType (locatedValue target) -> do
        receiverType <- runCheck checker declared rigid receiver
        resolved <- throughBorrow =<< zonk receiverType
        case targetName resolved of
          Nothing -> pure Nothing
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

{-| The type a borrow refers to, following as many references as were written.

    A `&&T` is unusual but writable, and stopping after one would report a
    confusing mismatch against a type the reader never intended to match on. -}
throughBorrow :: Type -> Checker Type
throughBorrow typeValue = do
  resolved <- zonk typeValue
  case resolved of
    ReferenceTypeValue _ referent -> throughBorrow referent
    _ -> pure resolved
