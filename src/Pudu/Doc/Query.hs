{-| @Doc.Query.Module — parses a search query into a name or a type shape -}
module Pudu.Doc.Query
  ( Query (..)
  , parseQuery
  , renderQuery
  ) where

import Data.Char (isAlpha, isAlphaNum, isSpace)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Doc.Signature (SigType (..), Signature (..), alphaNormalise, renderSignature)

{-| @Doc.Query.Value — what a reader typed.

    A query is either a name or a type. Nothing else is admitted: a query
    language that grew predicates would need its own grammar, its own errors,
    and its own documentation, and the two forms above answer the two questions
    a reader actually has — "where is this thing" and "what has this shape". -}
data Query
  = NameQuery !Text
  | TypeQuery !Signature
  deriving stock (Eq, Show)

{-| Parse a query.

    A query containing `->` is a type; anything else is a name. This is the
    whole disambiguation rule, and it is deliberately syntactic: a reader typing
    `sort` means the name, and a reader typing `Array[T] -> Array[T]` means the
    shape, and neither has to say which.

    A single type with no arrow — `Array[Int]` — is read as a name query too,
    because a bare capitalised word is far more often a type the reader wants to
    find than a nullary signature they want to match. `-> Array[Int]` asks for
    the shape. -}
parseQuery :: Text -> Maybe Query
parseQuery raw
  | Text.null trimmed = Nothing
  | Text.isInfixOf "->" trimmed = TypeQuery . alphaNormalise <$> parseSignature trimmed
  | otherwise = Just (NameQuery trimmed)
 where
  trimmed = Text.strip raw

{-| Split on top-level arrows and parse each piece.

    A trailing arrow with nothing after it is not a signature: `Int ->` says the
    reader was still typing, and inventing a result for them would answer a
    question they did not ask. -}
parseSignature :: Text -> Maybe Signature
parseSignature text = case splitArrows text of
  [] -> Nothing
  pieces -> do
    parts <- traverse parseSigType pieces
    case reverse parts of
      [] -> Nothing
      result : reversedArguments ->
        Just
          Signature
            { signatureConstraints = []
            , signatureArguments = reverse reversedArguments
            , signatureResult = result
            }

{-| Split on arrows that are not inside brackets or parentheses, so the inputs
    of a function-typed argument stay with it. -}
splitArrows :: Text -> [Text]
splitArrows = go 0 Text.empty
 where
  go :: Int -> Text -> Text -> [Text]
  go depth acc rest = case Text.uncons rest of
    Nothing -> [Text.strip acc]
    Just (scalar, remainder)
      | scalar `elem` ("[(" :: String) -> go (depth + 1) (Text.snoc acc scalar) remainder
      | scalar `elem` ("])" :: String) -> go (max 0 (depth - 1)) (Text.snoc acc scalar) remainder
      | depth == 0, scalar == '-', Text.isPrefixOf ">" remainder ->
          Text.strip acc : go 0 Text.empty (Text.drop 1 remainder)
      | otherwise -> go depth (Text.snoc acc scalar) remainder

{-| Parse one type atom.

    Lowercase leading letters are variables and uppercase ones are nominal
    types. Query text is not source, so there is no declaration to consult; the
    convention Hoogle established is the one readers already type, and it costs
    nothing to also accept an explicitly written variable. -}
parseSigType :: Text -> Maybe SigType
parseSigType raw
  | Text.null trimmed = Nothing
  | trimmed == "()" = Just SigUnit
  | trimmed == "_" || trimmed == "?" = Just SigUnknown
  | trimmed == "!" = Just SigNever
  | Text.isPrefixOf "&mut " trimmed = SigRef True <$> parseSigType (Text.drop 5 trimmed)
  | Text.isPrefixOf "&" trimmed = SigRef False <$> parseSigType (Text.drop 1 trimmed)
  | Text.isPrefixOf "fn(" trimmed = parseFunction trimmed
  | Text.isPrefixOf "(" trimmed, Text.isSuffixOf ")" trimmed = parseGrouped inner
  | Text.isSuffixOf "]" trimmed, Just (head', arguments) <- splitApplication trimmed =
      SigCon head' <$> traverse parseSigType (splitTop ',' arguments)
  | isIdentifier trimmed =
      Just $
        if isVariableName trimmed
          then SigVar trimmed
          else SigCon trimmed []
  | otherwise = Nothing
 where
  trimmed = Text.strip raw
  inner = Text.dropEnd 1 (Text.drop 1 trimmed)

{-| Parse `fn(A, B) -> C`, the way the language writes a function type.

    A function-typed argument must be parenthesised in a query — `(fn(Int) ->
    Str) -> Bool` — because an unparenthesised one is genuinely ambiguous with
    the query's own arrows, and guessing which arrow belonged to which would
    silently answer a different question than the reader asked. -}
parseFunction :: Text -> Maybe SigType
parseFunction text = do
  closing <- matchingParen (Text.drop 2 text)
  let inputText = Text.take (closing - 2) (Text.drop 3 text)
      rest = Text.strip (Text.drop (closing + 2) text)
  inputs <- traverse parseSigType (splitTop ',' inputText)
  case Text.stripPrefix "->" rest of
    Nothing -> Nothing
    Just resultText -> SigFun inputs <$> parseSigType resultText

{-| The offset just past the parenthesis that closes the one this text opens
    with, or nothing if it never closes. -}
matchingParen :: Text -> Maybe Int
matchingParen = go 0 (0 :: Int)
 where
  go index depth rest = case Text.uncons rest of
    Nothing -> Nothing
    Just (scalar, remainder)
      | scalar == '(' -> go (index + 1) (depth + 1) remainder
      | scalar == ')', depth == 1 -> Just (index + 1)
      | scalar == ')' -> go (index + 1) (depth - 1) remainder
      | otherwise -> go (index + 1) depth remainder

{-| A parenthesised query is a tuple when it has top-level commas and a grouping
    otherwise, matching how the language itself reads parentheses. -}
parseGrouped :: Text -> Maybe SigType
parseGrouped inner = case splitTop ',' inner of
  [] -> Just SigUnit
  [single] -> parseSigType single
  members -> SigTuple <$> traverse parseSigType members

{-| Split `Array[Int]` into its head and its arguments. -}
splitApplication :: Text -> Maybe (Text, Text)
splitApplication text = do
  index <- Text.findIndex (== '[') text
  let (head', rest) = Text.splitAt index text
      arguments = Text.dropEnd 1 (Text.drop 1 rest)
  if Text.null head' || not (isIdentifier head') then Nothing else Just (Text.strip head', arguments)

{-| Split on a separator that is not nested inside brackets or parentheses. -}
splitTop :: Char -> Text -> [Text]
splitTop separator = filter (not . Text.null) . map Text.strip . go 0 Text.empty
 where
  go :: Int -> Text -> Text -> [Text]
  go depth acc rest = case Text.uncons rest of
    Nothing -> [acc]
    Just (scalar, remainder)
      | scalar `elem` ("[(" :: String) -> go (depth + 1) (Text.snoc acc scalar) remainder
      | scalar `elem` ("])" :: String) -> go (max 0 (depth - 1)) (Text.snoc acc scalar) remainder
      | depth == 0, scalar == separator -> acc : go 0 Text.empty remainder
      | otherwise -> go depth (Text.snoc acc scalar) remainder

isIdentifier :: Text -> Bool
isIdentifier text = case Text.uncons text of
  Nothing -> False
  Just (scalar, rest) ->
    (isAlpha scalar || scalar == '_')
      && Text.all (\value -> isAlphaNum value || value == '_' || value == '.') rest
      && not (Text.any isSpace text)

{-| A one-letter or lowercase-leading name is a variable, following the
    convention every Hoogle user already types. -}
isVariableName :: Text -> Bool
isVariableName text = case Text.uncons text of
  Nothing -> False
  Just (scalar, rest) ->
    Set.notMember scalar uppercase && (Text.null rest || Text.all isAlphaNum rest)
 where
  uppercase = Set.fromList ['A' .. 'Z']

renderQuery :: Query -> Text
renderQuery query = case query of
  NameQuery name -> name
  TypeQuery signature -> renderSignature signature
