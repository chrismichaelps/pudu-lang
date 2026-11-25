{-| @Pudu.Eval.HtmlRender — `htmlRender(view, document)`: a `Std.Html.Html`
    page as the text `Std.Html.render` and `Std.Html.document` write. -}
module Pudu.Eval.HtmlRender (callHtmlRender) where

import Data.Char (isAsciiLower, isAsciiUpper, isDigit)
import Data.Foldable (toList)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as LazyText
import qualified Data.Text.Lazy.Builder as Builder
import qualified Data.Set as Set
import Pudu.Eval.Builtin.String (escapeHtmlText)
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (Value (..))
import Pudu.Source (Span)

callHtmlRender :: Span -> [Value] -> Evaluator Value
callHtmlRender spanValue arguments = case arguments of
  [view, BoolValue document] -> case page view of
    Just built ->
      let opened = if document then Builder.fromText "<!DOCTYPE html>\n" <> built else built
       in pure (StrValue (LazyText.toStrict (Builder.toLazyText opened)))
    Nothing -> abortAt (Just spanValue) "E7001" "htmlRender expects a Std.Html page" Nothing
  _ -> abortAt (Just spanValue) "E7012" "wrong arguments for htmlRender" Nothing

-- | The page's text, or nothing when the value is not a page.
page :: Value -> Maybe Builder.Builder
page value = case value of
  VariantValue "Text" [StrValue content] -> Just (Builder.fromText (escapeHtmlText content))
  VariantValue "Trusted" [StrValue markup] -> Just (Builder.fromText markup)
  VariantValue "Fragment" [ArrayValue children] -> mconcat <$> traverse page (toList children)
  VariantValue "Element" [StrValue name, ArrayValue attributes, ArrayValue children]
    | not (validName name) -> mconcat <$> traverse page (toList children)
    | otherwise -> do
        written <- mconcat <$> traverse attribute (toList attributes)
        inner <- mconcat <$> traverse page (toList children)
        let opening = Builder.singleton '<' <> Builder.fromText name <> written
        Just $ if Set.member name voidElements
          then opening <> Builder.fromText " />"
          else opening <> Builder.singleton '>' <> inner <> Builder.fromText "</" <> Builder.fromText name <> Builder.singleton '>'
  _ -> Nothing
 where
  attribute entry = case entry of
    TupleValue [StrValue key, StrValue held]
      | validName key && not (handler key) ->
          Just (Builder.singleton ' ' <> Builder.fromText key <> Builder.fromText "=\"" <> Builder.fromText (escapeHtmlText held) <> Builder.singleton '"')
      | otherwise -> Just mempty
    _ -> Nothing

-- | A letter, then letters, digits, '-', '_', '.' or ':'.
validName :: Text -> Bool
validName name = case Text.uncons name of
  Just (first, rest) -> letter first && Text.all (\character -> letter character || isDigit character || character `elem` ("-_.:" :: String)) rest
  Nothing -> False
 where
  letter character = isAsciiLower character || isAsciiUpper character

-- | A name whose trimmed, lowered spelling begins with "on".
handler :: Text -> Bool
handler name = "on" `Text.isPrefixOf` Text.toLower (Text.strip name)

voidElements :: Set.Set Text
voidElements = Set.fromList
  ["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"]
