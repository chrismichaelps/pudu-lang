{-| @Eval.Call.Path — dotted paths, qualified callees, and type argument syntax. -}
module Pudu.Eval.Call.Path
  ( flattenPath
  , lastPathSegment
  , longestBinding
  , pathValue
  , qualifiedCallee
  , qualifiedParts
  , readPath
  , typeArgumentName
  , typeArgumentNames
  ) where

import Data.Char (isUpper)
import Data.Foldable (toList)
import Data.List (inits)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Eval.Env (Evaluator, abortAt, lookupName)
import Pudu.Eval.Install (lastSegmentOf)
import Pudu.Eval.Loop (firstBound, receiverOwners)
import Pudu.Eval.Operator (readMember)
import Pudu.Eval.Value (Value (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Expression (..)
  , TypeSyntax (..)
  )
import Pudu.Source (Span)

{-| A two-segment path in callee position may select a method explicitly: by the
    type that implements it, as in `Bot.label(bot)`, or by the trait that
    declares it, as in `A.label(bot)`. The trait form dispatches on the first
    argument's type, which is the receiver the method is being called on. -}
qualifiedCallee :: Located Expression -> [Value] -> Evaluator (Maybe Value)
qualifiedCallee (Located _ expression) values = case qualifiedParts expression of
  Nothing -> pure Nothing
  Just (first, method) -> do
    direct <- lookupName (first <> "." <> method)
    case direct of
      Just found -> pure (Just found)
      Nothing -> case values of
        receiver : _ -> do
          owners <- receiverOwners receiver
          firstBound (\owner -> lookupName (first <> "." <> owner <> "." <> method)) owners
        [] -> pure Nothing

{-| A qualified callee reaches the parser as a member access on a bare name, so
    `A.label` and a two-segment path are the same selection written twice.
    Only names beginning with an uppercase letter are nominal types or traits;
    local variables and parameters cannot qualify method resolution. -}
qualifiedParts :: Expression -> Maybe (Text, Text)
qualifiedParts expression = case expression of
  NameExpression (first :| [method])
    | isNominalType first -> Just (first, method)
  MemberExpression (Located _ (NameExpression (first :| []))) member
    | isNominalType first -> Just (first, locatedValue member)
  _ -> Nothing
 where
  isNominalType name = case Text.uncons name of
    Just (c, _) -> isUpper c
    Nothing -> False

{-| Read a dotted path.

    A path may name a value and then reach into it, or it may name a linked
    module's member: `Std.List.sum` is one binding, while `point.x.y` is three
    reads. The longest resolving prefix decides which, because a module path is
    always fully written and a value's own name never contains a dot — so the
    longer match is the one the reader meant, and preferring it cannot shadow a
    local. -}
readPath :: Span -> NonEmpty Text -> Evaluator Value
readPath spanValue path@(first :| rest) = do
  linked <- longestBinding path
  case linked of
    Just (value, remaining) -> foldMember value remaining
    Nothing -> do
      found <- lookupName first
      base <- case found of
        Just value -> pure value
        Nothing -> abortAt (Just spanValue) "E7001" ("undefined name " <> first) Nothing
      foldMember base rest
 where
  foldMember value segments = case segments of
    [] -> pure value
    segment : remaining -> do
      next <- readMember spanValue value segment
      foldMember next remaining

{-| A member chain read as one dotted name, when every part of it is a plain
    identifier and the whole thing is bound. Anything else is `Nothing`, so an
    ordinary field read is untouched. -}
pathValue :: Expression -> Evaluator (Maybe Value)
pathValue expression = case flattenPath expression of
  Nothing -> pure Nothing
  Just path -> lookupName (Text.intercalate "." path)

{-| The last segment of a module's dotted name. -}
lastPathSegment :: ModuleName -> Text
lastPathSegment (ModuleName segments) = lastSegmentOf segments

{-| The segments of a chain of names and member accesses, or nothing when any
    part of it is a real expression. -}
flattenPath :: Expression -> Maybe [Text]
flattenPath expression = case expression of
  NameExpression names -> Just (toList names)
  MemberExpression (Located _ target) member ->
    (<> [locatedValue member]) <$> flattenPath target
  _ -> Nothing

{-| The longest dotted prefix of a path that is bound, with the segments it did
    not consume. A single segment is not reported here: it is the ordinary case
    and the caller handles it without this search. -}
longestBinding :: NonEmpty Text -> Evaluator (Maybe (Value, [Text]))
longestBinding (first :| rest) = search (reverse (prefixes rest))
 where
  prefixes segments =
    [ (Text.intercalate "." (first : taken), drop (length taken) segments)
    | taken <- drop 1 (inits segments)
    ]

  search [] = pure Nothing
  search ((name, remaining) : shorter) = do
    found <- lookupName name
    case found of
      Just value -> pure (Just (value, remaining))
      Nothing -> search shorter

{-| The type arguments a callee carries, and the callee under them. -}
typeArgumentNames :: Expression -> Maybe ([Text], Located Expression)
typeArgumentNames expression = case expression of
  TypeApplication inner arguments -> Just (map typeArgumentName arguments, inner)
  _ -> Nothing

{-| A written type's name, or empty when it was not a plain nominal one. -}
typeArgumentName :: Located TypeSyntax -> Text
typeArgumentName located = case locatedValue located of
  NamedType path _ -> moduleNameText path
  _ -> Text.empty
