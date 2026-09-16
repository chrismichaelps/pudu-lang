{-| @Program.Lint.Config.Module — closed project and source lint policy. -}
module Pudu.Lint.Config
  ( Allowances (..)
  , projectAllowances
  , sourceAllowances
  , suppressed
  , warningCode
  ) where

import Control.Exception (IOException, try)
import Control.Monad (foldM)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler.Manifest (findManifestRoot)
import Pudu.Diagnostic
  ( Diagnostic
  , diagnosticCode
  , diagnosticCodeText
  , diagnosticSpan
  )
import Pudu.Source
  ( Position (..)
  , Source
  , SourceName (..)
  , offsetPosition
  , sourceName
  , sourceText
  , spanStart
  )
import System.FilePath ((</>), takeDirectory)

data Allowances = Allowances
  { allowanceFile :: !(Set Text)
  , allowanceNext :: !(Map Int (Set Text))
  }

projectAllowances :: FilePath -> IO (Either Text (Set Text))
projectAllowances path = do
  root <- findManifestRoot (takeDirectory path)
  case root of
    Nothing -> pure (Right Set.empty)
    Just directory -> do
      let manifest = directory </> "pudu.toml"
      loaded <- try (TextIO.readFile manifest) :: IO (Either IOException Text)
      pure $ case loaded of
        Left problem -> Left
          ("pudu lint: cannot read " <> Text.pack manifest <> ": " <> Text.pack (show problem))
        Right contents -> parseProjectAllow manifest contents

sourceAllowances :: Source -> Either Text Allowances
sourceAllowances source =
  foldM line (Allowances Set.empty Map.empty)
    (zip [1 :: Int ..] (Text.lines (sourceText source)))
 where
  line state (lineNumber, raw) = case Text.stripPrefix "//" (Text.stripStart raw) of
    Nothing -> Right state
    Just comment -> case Text.stripPrefix "pudu-lint:" (Text.stripStart comment) of
      Nothing -> Right state
      Just directive -> parseDirective source lineNumber state (Text.words directive)

suppressed :: Allowances -> Set Text -> Source -> Diagnostic -> Bool
suppressed sourceAllowed allowed source value =
  let code = diagnosticCodeText (diagnosticCode value)
      line = positionLine <$> offsetPosition source (spanStart (diagnosticSpan value))
   in Set.member code (allowed <> allowanceFile sourceAllowed)
        || maybe False
          (\lineNumber -> Set.member code
            (Map.findWithDefault Set.empty lineNumber (allowanceNext sourceAllowed)))
          line

parseDirective :: Source -> Int -> Allowances -> [Text] -> Either Text Allowances
parseDirective source lineNumber state wordsValue = case wordsValue of
  action : codes | action == "allow-file" -> do
    admitted <- codeSet source lineNumber codes
    pure state{allowanceFile = allowanceFile state <> admitted}
  action : codes | action == "allow-next" -> do
    admitted <- codeSet source lineNumber codes
    pure state{allowanceNext = Map.insertWith (<>) (lineNumber + 1) admitted (allowanceNext state)}
  _ -> Left
    (directiveError source lineNumber "expected allow-file or allow-next followed by warning codes")

codeSet :: Source -> Int -> [Text] -> Either Text (Set Text)
codeSet source lineNumber codes
  | null codes = Left (directiveError source lineNumber "at least one warning code is required")
  | otherwise = Set.fromList <$> traverse validate codes
 where
  validate code = case warningCode code of
    Left problem -> Left (directiveError source lineNumber problem)
    Right valid -> Right valid

directiveError :: Source -> Int -> Text -> Text
directiveError source lineNumber problem =
  sourcePath source <> ":" <> Text.pack (show lineNumber)
    <> ": invalid pudu-lint directive: " <> problem

parseProjectAllow :: FilePath -> Text -> Either Text (Set Text)
parseProjectAllow path contents = go "" Nothing (zip [1 :: Int ..] (Text.lines contents))
 where
  go _ found [] = Right (maybe Set.empty id found)
  go section found ((lineNumber, raw) : rest) =
    let trimmed = Text.strip (dropTomlComment raw)
     in case Text.stripPrefix "[" trimmed >>= Text.stripSuffix "]" of
          Just heading -> go (Text.strip heading) found rest
          Nothing
            | section == "lint", Just value <- assignment "allow" trimmed -> case found of
                Just _ -> Left (manifestError lineNumber "lint.allow may appear only once")
                Nothing -> case parseCodeArray value of
                  Left problem -> Left (manifestError lineNumber problem)
                  Right parsed -> go section (Just parsed) rest
            | otherwise -> go section found rest
  manifestError lineNumber problem =
    Text.pack path <> ":" <> Text.pack (show lineNumber) <> ": " <> problem

parseCodeArray :: Text -> Either Text (Set Text)
parseCodeArray value = case Text.stripPrefix "[" (Text.strip value) >>= Text.stripSuffix "]" of
  Nothing -> Left "lint.allow must be an array of quoted warning codes"
  Just inner
    | Text.null (Text.strip inner) -> Right Set.empty
    | otherwise -> Set.fromList <$> traverse parseItem (Text.splitOn "," inner)
 where
  parseItem item = case Text.stripPrefix "\"" (Text.strip item) >>= Text.stripSuffix "\"" of
    Nothing -> Left "lint.allow entries must be quoted warning codes"
    Just code -> warningCode code

assignment :: Text -> Text -> Maybe Text
assignment expected line = case Text.breakOn "=" line of
  (key, rest) | Text.strip key == expected && not (Text.null rest) -> Just (Text.drop 1 rest)
  _ -> Nothing

{-| Remove a TOML comment without treating a quoted hash as one. -}
dropTomlComment :: Text -> Text
dropTomlComment = Text.pack . walk Nothing False . Text.unpack
 where
  walk _ _ [] = []
  walk quoted escaped (character : rest) = case (quoted, escaped, character) of
    (Just quote, True, _) -> character : walk (Just quote) False rest
    (Just quote, False, '\\') | quote == '"' -> character : walk quoted True rest
    (Just quote, False, value) | value == quote -> value : walk Nothing False rest
    (Just _, False, _) -> character : walk quoted False rest
    (Nothing, _, '#') -> []
    (Nothing, _, value) | value == '"' || value == '\'' ->
      value : walk (Just value) False rest
    (Nothing, _, _) -> character : walk Nothing False rest

warningCode :: Text -> Either Text Text
warningCode code = case Text.unpack code of
  ['W', group, first, second, third]
    | group >= '0', group <= '7', all asciiDigit [first, second, third] ->
        if Set.member code knownWarningCodes
          then Right code
          else Left ("unknown warning code " <> code)
  _ -> Left ("invalid warning code " <> code)
 where
  asciiDigit value = value >= '0' && value <= '9'

knownWarningCodes :: Set Text
knownWarningCodes = Set.fromList
  [ "W2001", "W2002", "W3001", "W3002", "W3003", "W5001", "W7027", "W7101" ]

sourcePath :: Source -> Text
sourcePath source = case sourceName source of SourceName path -> path
