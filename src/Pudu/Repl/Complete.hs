{-| @Repl.Complete.Module — completes commands, paths, and names -}
module Pudu.Repl.Complete
  ( CompletionSource (..)
  , completionsFor
  , memberContext
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
  | wantsShowTopic before = matching word showTopics
  | wantsSettingFlag before = matching word settingFlags
  | wantsBrowseModule before = matching word (stdModuleNames <> sourceSessionNames source)
  | otherwise = matching word (namePool source)

isCommandPosition :: Text -> Text -> Bool
isCommandPosition before word =
  Text.null (Text.strip before) && Text.isPrefixOf ":" word

wantsShowTopic :: Text -> Bool
wantsShowTopic before = case Text.words (Text.strip before) of
  [cmd] -> cmd `elem` [":show", ":s"] && Text.isSuffixOf " " before
  _ -> False

showTopics :: [Text]
showTopics = ["bindings", "declarations", "imports", "settings"]

wantsSettingFlag :: Text -> Bool
wantsSettingFlag before = case Text.words (Text.strip before) of
  [cmd] -> cmd `elem` [":set", ":unset"] && Text.isSuffixOf " " before
  _ -> False

settingFlags :: [Text]
settingFlags = ["+t", "+s", "+trunc"]

wantsBrowseModule :: Text -> Bool
wantsBrowseModule before = case Text.words (Text.strip before) of
  [cmd] -> cmd `elem` [":browse", ":b"] && Text.isSuffixOf " " before
  _ -> False

stdModuleNames :: [Text]
stdModuleNames =
  [ "Std.BitSet"
  , "Std.BitVector"
  , "Std.BloomFilter"
  , "Std.Buffer"
  , "Std.Bytes"
  , "Std.Crypto"
  , "Std.Crypto.Crc32"
  , "Std.Db"
  , "Std.Diff"
  , "Std.Env"
  , "Std.FlatMap"
  , "Std.Hash"
  , "Std.HashMap"
  , "Std.Html"
  , "Std.Http"
  , "Std.Http.Client"
  , "Std.Http.Safe"
  , "Std.Http.Server"
  , "Std.IntMap"
  , "Std.IntSet"
  , "Std.Io"
  , "Std.Iter"
  , "Std.Json"
  , "Std.List"
  , "Std.Log"
  , "Std.Math"
  , "Std.Math.Float"
  , "Std.Mime"
  , "Std.Net"
  , "Std.Option"
  , "Std.Path"
  , "Std.Process"
  , "Std.Random"
  , "Std.Regex"
  , "Std.Result"
  , "Std.Set"
  , "Std.Test"
  , "Std.Text"
  , "Std.Time"
  , "Std.Uuid"
  ]

{-| Where the cursor is completing a member of something, and what that
    something is.

    Returns the text of the receiver and the part of the member name already
    typed. `[1, 2].` gives `("[1, 2]", "")` and `"hello".le` gives
    `("\"hello\"", "le")`, so the caller can ask what the receiver is and offer
    the methods that type carries. -}
memberContext :: Text -> Text -> Maybe (Text, Text)
memberContext before word
  | Text.isPrefixOf "." word = case Text.strip before of
      receiver | not (Text.null receiver) -> Just (receiver, Text.drop 1 word)
      _ -> Nothing
  | otherwise = Nothing

{-| A filename is wanted after a command that takes one, once its name is
    complete and a space has been typed. -}
wantsFilename :: Text -> Bool
wantsFilename before = case Text.words (Text.strip before) of
  command : _ -> Text.isPrefixOf ":" command && isFileCommand (Text.drop 1 command)
  [] -> False
 where
  isFileCommand typed =
    not (Text.null typed)
      && (Text.isPrefixOf typed "load" || Text.isPrefixOf typed "edit")
      && Text.isSuffixOf " " before

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
