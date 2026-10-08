{-| @Eval.Call.Path — dotted paths, qualified callees, and type argument syntax. -}
module Pudu.Eval.Call.Path
  ( flattenPath
  , lastPathSegment
  , longestBinding
  , pathValue
  , qualifiedCallee
  , qualifiedParts
  , qualifiedPath
  , readPath
  , readName
  , typeArgumentName
  , typeArgumentNames
  , selectTypes
  , witnessOf
  ) where

import Data.Char (isUpper)
import Data.Foldable (toList)
import Data.List (inits)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Eval.Env (Evaluator, abortAt, lookupLocal, lookupName)
import Pudu.Eval.Install (lastSegmentOf)
import Pudu.Eval.Loop (firstBound, receiverOwners)
import Pudu.Eval.Operator (readMember)
import Pudu.Eval.Value (Closure (..), Value (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Expression (..)
  , Function (..)
  , TypeParam (..)
  , TypeSyntax (..)
  )
import Pudu.Source (Span, spanOrigin)

{-| A two-segment path in callee position may select a method explicitly: by the
    type that implements it, as in `Bot.label(bot)`, or by the trait that
    declares it, as in `A.label(bot)`. The trait form dispatches on the first
    argument's type, which is the receiver the method is being called on. -}
qualifiedCallee :: Located Expression -> [Value] -> Evaluator (Maybe Value)
qualifiedCallee (Located _ expression) values = case qualifiedParts expression of
  Nothing -> pure Nothing
  Just (first, method) -> do
    local <- lookupLocal first
    direct <- case local of
      Just witness@TypeWitnessValue{} -> witnessMethod witness method
      Just _ -> pure Nothing
      Nothing -> lookupName (first <> "." <> method)
    case direct of
      Just found -> pure (Just found)
      Nothing | not (qualifies local) -> pure Nothing
      Nothing -> case values of
        receiver : _ -> do
          owners <- receiverOwners receiver
          firstBound (\owner -> lookupName (first <> "." <> owner <> "." <> method)) owners
        [] -> pure Nothing

{-| A qualified callee reaches the parser as a member access on a bare name, so
    `A.label` and a two-segment path are the same selection written twice.
    Uppercase spelling filters candidates; a local constant still has to pass
    lexical admission before it can qualify method resolution. -}
qualifiedParts :: Expression -> Maybe (Text, Text)
qualifiedParts expression = case expression of
  NameExpression (first :| [method])
    | isNominalType first -> Just (first, method)
  MemberExpression (Located _ (NameExpression (first :| []))) member
    | isNominalType first -> Just (first, locatedValue member)
  -- Generated code names an owner canonically, `Module.Type`; methods are
  -- installed under the type's own name.
  MemberExpression (Located at (NameExpression path@(_ :| (_ : _)))) member
    | Just _ <- spanOrigin at, isNominalType (lastSegmentOf path) ->
        Just (lastSegmentOf path, locatedValue member)
  _ -> Nothing
 where
  isNominalType name = case Text.uncons name of
    Just (c, _) -> isUpper c
    Nothing -> False

{-| A nominal-looking path may instead start with an ordinary local constant. -}
qualifiedPath :: Expression -> Evaluator Bool
qualifiedPath expression = case flattenPath expression of
  Just (first : _) | Just (initial, _) <- Text.uncons first, isUpper initial ->
    qualifies <$> lookupLocal first
  _ -> pure False

qualifies :: Maybe Value -> Bool
qualifies Nothing = True
qualifies (Just TypeWitnessValue{}) = True
qualifies (Just _) = False

{-| Read a dotted path.

    A path may name a value and then reach into it, or it may name a linked
    module's member: `Std.List.sum` is one binding, while `point.x.y` is three
    reads. The longest resolving prefix decides which, because a module path is
    always fully written and a value's own name never contains a dot — so the
    longer match is the one the reader meant, and preferring it cannot shadow a
    local. -}
readPath :: Span -> NonEmpty Text -> Evaluator Value
readPath spanValue (name :| []) = readName spanValue name
readPath spanValue path@(first :| rest) = do
  local <- if null rest then pure Nothing else lookupLocal first
  linked <- case (local, rest) of
    (Just witness@TypeWitnessValue{}, [member]) -> do
      method <- witnessMethod witness member
      pure (fmap (\found -> (found, [])) method)
    (Just value, _) -> pure (Just (value, rest))
    (Nothing, _) -> longestBinding path
  case linked of
    Just (value, remaining) -> foldMember value remaining
    Nothing -> do
      found <- lookupName first
      case found of
        Just value -> foldMember value rest
        -- A derive's construction names a variant by its canonical owner,
        -- which the defining module need not import; the checker proved the
        -- path, and a variant value carries only its tag.
        Nothing | Just _ <- spanOrigin spanValue -> pure (VariantValue (lastSegmentOf path) [])
        Nothing -> abortAt (Just spanValue) "E7001" ("undefined name " <> first) Nothing
 where
  foldMember value segments = case segments of
    [] -> pure value
    segment : remaining -> do
      next <- readMember spanValue value segment
      foldMember next remaining

readName :: Span -> Text -> Evaluator Value
{-# INLINE readName #-}
readName spanValue name = do
  found <- lookupName name
  case found of
    Just value -> pure value
    Nothing -> abortAt (Just spanValue) "E7001" ("undefined name " <> name) Nothing

{-| A member chain read as one dotted name, when every part of it is a plain
    identifier and the whole thing is bound. Anything else is `Nothing`, so an
    ordinary field read is untouched. -}
pathValue :: Expression -> Evaluator (Maybe Value)
pathValue expression = case flattenPath expression of
  Nothing -> pure Nothing
  Just [] -> pure Nothing
  Just path@(first : _) -> do
    local <- lookupLocal first
    case local of
      Just _ -> pure Nothing
      Nothing -> lookupName (Text.intercalate "." path)

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

{-| The method a witnessed owner installs under this name, holding the
    owner's own arguments for the implementation's leading parameters. -}
witnessMethod :: Value -> Text -> Evaluator (Maybe Value)
witnessMethod witness member = case witness of
  TypeWitnessValue owner arguments -> do
    found <- lookupName (owner <> "." <> member)
    pure $ case found of
      Just (FunctionValue closure) -> Just (FunctionValue (selectTypes arguments closure))
      other -> other
  _ -> pure Nothing

{-| Bind chosen types to a closure's type parameters in declaration order;
    an installed method's parameters begin with its implementation's. -}
selectTypes :: [Value] -> Closure -> Closure
selectTypes [] closure = closure
selectTypes chosen closure = closure
  { closureWitnesses =
      zip (map (locatedValue . typeParamName . locatedValue) (functionTypeParams (closureFunction closure))) chosen
        <> closureWitnesses closure
  }

{-| The witness a written type stands for. A one-segment name bound to a
    witness is a parameter the enclosing call selected; any other nominal is
    its own owner, named by its last segment as methods are installed. -}
witnessOf :: Located TypeSyntax -> Evaluator Value
witnessOf (Located _ written) = case written of
  NamedType path@(ModuleName (first :| rest)) arguments -> do
    local <- if null rest && null arguments then lookupLocal first else pure Nothing
    case local of
      Just witness@TypeWitnessValue{} -> pure witness
      _ -> TypeWitnessValue (lastSegmentOf (moduleNameSegments' path)) <$> mapM witnessOf arguments
  _ -> pure (TypeWitnessValue Text.empty [])
 where
  moduleNameSegments' (ModuleName segments) = segments
