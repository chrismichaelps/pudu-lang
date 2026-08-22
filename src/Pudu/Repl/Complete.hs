{-| @Repl.Complete.Module — completes commands, paths, and names -}
module Pudu.Repl.Complete
  ( CompletionSource (..)
  , completionsFor
  , isNameCharacter
  , keywordNames
  , wantsFilename
  ) where

import Data.Char (isAlphaNum)
import Data.List (nub, sort)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Token (Keyword, keywordText)
import Pudu.Repl.Command (commandNames)
import Pudu.Semantic.Prelude (preludeTypeNames, preludeValueNames, wiredInTypeNames)

{-| @Repl.Complete.Source — what a session can offer as completions.

    The names come from the session itself rather than a fixed list, so a
    declaration made at the prompt is completable on the next line. -}
data CompletionSource = CompletionSource
  { sourceSessionNames :: ![Text]
  }
  deriving stock (Eq, Show)

{-| Complete the word under the cursor.

    A word that starts the line with `:` completes commands; anything else
    completes a name. The line before the word decides whether a filename is
    wanted, which the caller handles because only it can read the filesystem. -}
completionsFor :: CompletionSource -> Text -> Text -> [Text]
completionsFor source before word
  | isCommandPosition before word = map (":" <>) (matching (Text.drop 1 word) commandNames)
  | otherwise = matching word (namePool source)

isCommandPosition :: Text -> Text -> Bool
isCommandPosition before word =
  Text.null (Text.strip before) && Text.isPrefixOf ":" word

{-| A filename is wanted after a command that takes one, once its name is
    complete and a space has been typed. -}
wantsFilename :: Text -> Bool
wantsFilename before = case Text.words (Text.strip before) of
  command : _ -> Text.isPrefixOf ":" command && isLoadCommand (Text.drop 1 command)
  [] -> False
 where
  isLoadCommand typed =
    not (Text.null typed) && Text.isPrefixOf typed "load" && Text.isSuffixOf " " before

matching :: Text -> [Text] -> [Text]
matching word candidates = sort (nub (filter (Text.isPrefixOf word) candidates))

{-| Every name a reader can type: the closed keyword vocabulary, the wired-in
    types, the implicit prelude, and whatever the session declared. -}
namePool :: CompletionSource -> [Text]
namePool source =
  keywordNames
    <> wiredInTypeNames
    <> preludeTypeNames
    <> preludeValueNames
    <> sourceSessionNames source

keywordNames :: [Text]
keywordNames = map keywordText allKeywords

allKeywords :: [Keyword]
allKeywords = [minBound .. maxBound]

{-| Identifier characters for completion: the same set the lexer admits in a
    name, plus `.` so a qualified path completes as one word. -}
isNameCharacter :: Char -> Bool
isNameCharacter character = isAlphaNum character || character == '_' || character == '.'
