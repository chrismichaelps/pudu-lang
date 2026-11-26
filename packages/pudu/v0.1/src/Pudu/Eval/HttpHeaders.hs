{-| @Pudu.Eval.HttpHeaders — `httpHeaderPairs(head)`: the header pairs of a
    request head every line of which `Std.Http.Message` takes whole, or none,
    which asks the caller to read the head itself. -}
module Pudu.Eval.HttpHeaders (callHttpHeaders) where

import Data.Char (isAlphaNum, isAscii, isSpace)
import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (Value (..))
import Pudu.Source (Span)

callHttpHeaders :: Span -> [Value] -> Evaluator Value
callHttpHeaders spanValue arguments = case arguments of
  [StrValue head'] -> pure (ArrayValue (Seq.fromList [TupleValue [StrValue name, StrValue value] | (name, value) <- maybe [] id (pairs head')]))
  _ -> abortAt (Just spanValue) "E7012" "wrong arguments for httpHeaderPairs" Nothing

pairs :: Text -> Maybe [(Text, Text)]
pairs head' = do
  let separator = if "\r\n" `Text.isInfixOf` head' then "\r\n" else "\n"
      raw = Text.splitOn separator head'
      lines' = if not (null raw) && Text.null (last raw) then init raw else raw
  found <- traverse field (filter (not . Text.null) (drop 1 lines'))
  if null found then Nothing else Just found
 where
  field line
    | Text.isPrefixOf " " line || Text.isPrefixOf "\t" line = Nothing
    | Text.any (\c -> c == '\r' || c == '\n') line = Nothing
    | otherwise = case Text.breakOn ":" line of
        (name, rest)
          | Text.null rest -> Nothing
          | token name -> Just (name, Text.dropAround isSpace (Text.drop 1 rest))
          | otherwise -> Nothing
  token name = not (Text.null name) && Text.all (\c -> (isAscii c && isAlphaNum c) || c `elem` ("!#$%&'*+-.^_`|~" :: String)) name
