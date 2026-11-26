{-| @Type.Ownership.Pattern — what a pattern binds and which parts it leaves behind -}
module Pudu.Type.Ownership.Pattern
  ( checkPattern
  ) where

import Control.Monad (forM_, when, zipWithM_)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree (FieldPattern (..), Pattern (..))
import Pudu.Source (Span)
import Pudu.Type.Drop (implementsDrop, needsDrop, substituteParameters)
import Pudu.Type.Env (Checker, lookupField, lookupTypeParams, lookupVariant)
import Pudu.Type.Ownership.Flow (Walk, lift, refuse)
import Pudu.Type.Value (NominalId (..), Type (..))

{-| A pattern over a value that needs drop takes ownership of what it binds,
    so every part that needs drop must be bound by name: a part left behind
    would have no owner to drop it. A type that implements `Drop` is never
    taken apart, because its `drop` needs the whole value. -}
checkPattern :: Maybe Type -> Located Pattern -> Walk ()
checkPattern subject located@(Located at pattern) = case subject of
  Nothing -> pure ()
  Just typeValue -> do
    owning <- lift (needsDrop typeValue)
    when owning (inspect at typeValue located pattern)

inspect :: Span -> Type -> Located Pattern -> Pattern -> Walk ()
inspect at typeValue located pattern = case pattern of
  WildcardPattern -> leftBehind at
  BindingPattern _ -> pure ()
  TuplePattern parts -> case typeValue of
    TupleTypeValue members -> zipWithM_ (checkPattern . Just) members parts
    _ -> pure ()
  ArrayPattern{} -> pure ()
  AlternativePattern alternatives -> mapM_ (checkPattern (Just typeValue)) alternatives
  ConstructorPattern path parts -> whole typeValue $ \owner arguments -> do
    payload <- variantPayload owner arguments (variantName path)
    zipWithM_ (checkPattern . Just) payload parts
  RecordPattern _ fields _ -> whole typeValue $ \owner arguments -> do
    written <- lift (fieldTypes owner arguments)
    forM_ written $ \(name, fieldType) ->
      case [field | Located _ field <- fields, locatedValue (fieldPatternName field) == name] of
        field : _ -> forM_ (fieldPatternValue field) (checkPattern (Just fieldType))
        [] -> do
          owning <- lift (needsDrop fieldType)
          when owning (leftBehind at)
  _ -> pure ()
 where
  whole held continue = case held of
    NominalType owner arguments -> do
      own <- lift (implementsDrop owner)
      if own
        then refuse "E4009" (locatedSpan located)
          ("a " <> nominalName owner <> " cannot be taken apart: its drop needs the whole value")
          "bind the whole value to a name and read its fields through that name"
        else continue owner arguments
    _ -> pure ()

leftBehind :: Span -> Walk ()
leftBehind at =
  refuse "E4007" at "this part of the value needs drop and is not bound"
    "bind it to a name so it has an owner that drops it"

variantName :: ModuleName -> Text
variantName (ModuleName segments) = NonEmpty.last segments

variantPayload :: NominalId -> [Type] -> Text -> Walk [Type]
variantPayload owner arguments name = case (nominalName owner, name, arguments) of
  ("Option", "Some", [inner]) -> pure [inner]
  ("Result", "Ok", [success, _]) -> pure [success]
  ("Result", "Err", [_, failure]) -> pure [failure]
  ("Option", _, _) -> pure []
  ("Result", _, _) -> pure []
  _ -> lift $ do
    params <- lookupTypeParams owner
    found <- lookupVariant name
    let substitution = zip (fromMaybe [] params) arguments
    pure $ case found of
      Just (_, _, payload) -> map (substituteParameters substitution) payload
      Nothing -> []

fieldTypes :: NominalId -> [Type] -> Checker [(Text, Type)]
fieldTypes owner arguments = do
  params <- lookupTypeParams owner
  fields <- lookupField owner
  let substitution = zip (fromMaybe [] params) arguments
  pure [(name, substituteParameters substitution held) | (name, held) <- fromMaybe [] fields]
