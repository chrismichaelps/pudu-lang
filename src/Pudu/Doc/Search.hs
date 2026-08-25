{-| @Doc.Search.Module — ranks index entries against a query -}
module Pudu.Doc.Search
  ( Match (..)
  , searchIndex
  , searchText
  ) where

import Data.List (sortOn)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Doc (DocEntry (..), DocIndex (..))
import Pudu.Doc.Query (Query (..), parseQuery)
import Pudu.Doc.Signature
  ( SigType (..)
  , Signature (..)
  , alphaNormalise
  , signatureArity
  )

{-| @Doc.Search.Match — one result and how well it answered.

    The score is exposed rather than hidden inside the ordering so that a caller
    merging results from several modules can rank them together. A tool that
    could only ask "what came first in this list" would have to re-derive the
    comparison it was already given. -}
data Match = Match
  { matchEntry :: !DocEntry
  , matchScore :: !Int
  }
  deriving stock (Eq, Show)

{-| Search an index with a raw query string. -}
searchText :: Text -> DocIndex -> [Match]
searchText raw index = case parseQuery raw of
  Nothing -> []
  Just query -> searchIndex query index

{-| Search an index, best answers first.

    Ties keep declaration order, so a module's own arrangement survives when the
    ranking has nothing to say. -}
searchIndex :: Query -> DocIndex -> [Match]
searchIndex query index =
  sortOn matchScore (mapMaybe (scoreEntry query) (indexEntries index))

scoreEntry :: Query -> DocEntry -> Maybe Match
scoreEntry query entry = case query of
  NameQuery name -> Match entry <$> nameScore name (docName entry)
  TypeQuery wanted -> do
    signature <- docSignature entry
    Match entry <$> shapeScore wanted (alphaNormalise signature)

{-| Score a name query.

    Exact beats prefix beats infix beats a scattered subsequence, which is the
    order a reader's confidence decreases in. A query that matches nothing at
    all scores nothing rather than a large number, because a bad match at the
    bottom of a list is still a claim that it matched. -}
nameScore :: Text -> Text -> Maybe Int
nameScore wanted found
  | lowerWanted == lowerFound = Just 0
  | Text.isPrefixOf lowerWanted lowerFound = Just 10
  | Text.isInfixOf lowerWanted lowerFound = Just 20
  | isSubsequence lowerWanted lowerFound = Just 30
  | otherwise = Nothing
 where
  lowerWanted = Text.toLower wanted
  lowerFound = Text.toLower found

{-| Score a type query against a signature.

    Four things are worth reporting, in decreasing order of how well they answer
    the question:

    * the same shape, up to variable naming
    * the same shape once the arguments are reordered — a reader who wants
      `Int -> Array[T] -> T` will accept `Array[T] -> Int -> T`
    * the query's arguments appearing among a longer argument list with the same
      result, which finds the function that takes one more configuration
      argument than the reader expected
    * the same result alone, which is the weakest honest answer: "this produces
      what you asked for"

    A query more specific than the signature still matches, because a signature
    is polymorphic exactly so a concrete query can be answered by it. The
    reverse — a polymorphic query against a concrete signature — matches only
    through the weaker rules, since `T -> T` genuinely does not describe
    `Int -> Int` to a caller who needed it for `Str`. -}
shapeScore :: Signature -> Signature -> Maybe Int
shapeScore wanted found
  | sameShape = Just 0
  | reorderedShape = Just 40
  | sameResult && null wantedArguments = Just 60
  | argumentsContained && sameResult = Just 50
  | otherwise = Nothing
 where
  wantedArguments = signatureArguments wanted
  foundArguments = signatureArguments found

  sameShape =
    signatureArity wanted == signatureArity found
      && and (zipWith compatible wantedArguments foundArguments)
      && compatible (signatureResult wanted) (signatureResult found)

  reorderedShape =
    signatureArity wanted == signatureArity found
      && compatible (signatureResult wanted) (signatureResult found)
      && consumesAll wantedArguments foundArguments

  argumentsContained = consumesAll wantedArguments foundArguments

  sameResult = compatible (signatureResult wanted) (signatureResult found)

{-| Every wanted argument is matched by a distinct found argument. -}
consumesAll :: [SigType] -> [SigType] -> Bool
consumesAll [] _ = True
consumesAll (wanted : rest) available = case break (compatible wanted) available of
  (_, []) -> False
  (before, _ : after) -> consumesAll rest (before <> after)

{-| Whether a signature's type can answer a query's type.

    A variable in the *signature* accepts anything, because that is what being
    polymorphic means. A variable in the *query* matches only another variable,
    because a reader who wrote a variable asked for a function that works for
    every type, and a concrete one does not. `SigUnknown` matches anything in
    either direction: it means the compiler could not say, and refusing to match
    would hide the entry rather than qualify it. -}
compatible :: SigType -> SigType -> Bool
compatible wanted found = case (wanted, found) of
  (SigUnknown, _) -> True
  (_, SigUnknown) -> True
  (_, SigVar _) -> True
  (SigVar _, _) -> False
  (SigCon leftName leftArguments, SigCon rightName rightArguments) ->
    leftName == rightName
      && length leftArguments == length rightArguments
      && and (zipWith compatible leftArguments rightArguments)
  (SigRef leftMutable leftTarget, SigRef rightMutable rightTarget) ->
    leftMutable == rightMutable && compatible leftTarget rightTarget
  (SigTuple leftMembers, SigTuple rightMembers) ->
    length leftMembers == length rightMembers && and (zipWith compatible leftMembers rightMembers)
  (SigFun leftInputs leftResult, SigFun rightInputs rightResult) ->
    length leftInputs == length rightInputs
      && and (zipWith compatible leftInputs rightInputs)
      && compatible leftResult rightResult
  (SigUnit, SigUnit) -> True
  (SigNever, _) -> True
  (_, SigNever) -> True
  _ -> False

{-| Whether every scalar of the first text appears in order in the second. -}
isSubsequence :: Text -> Text -> Bool
isSubsequence wanted found = Text.foldl' step (Text.unpack wanted) found == []
 where
  step [] _ = []
  step (next : rest) scalar
    | next == scalar = rest
    | otherwise = next : rest
