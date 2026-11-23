{-| @Backend.Identity — what an application is called, which version it is,
    and which links open it.

    The manifest's `[app]` table names the application people see, its
    reverse-DNS identifier, the version people read and the build number
    stores require to rise, and the URL schemes it opens. Each value is
    checked before anything is built, so a store or platform never sees an
    identifier, version or scheme it would refuse; a key left out keeps the
    default the build derives from the program's file name. -}
module Pudu.Backend.Identity
  ( Identity (..)
  , IdentityProblem (..)
  , defaultIdentity
  , settleIdentity
  ) where

import Data.Char (isAsciiLower, isAsciiUpper, isDigit)
import Data.Text (Text)
import qualified Data.Text as Text
import Text.Read (readMaybe)

{-| An application's identity: its shown name, identifier, version, build and
    the URL schemes it opens. -}
data Identity = Identity
  { identityName :: !Text
  , identityIdentifier :: !Text
  , identityVersion :: !Text
  , identityBuild :: !Int
  , identitySchemes :: ![Text]
  , identityDeclared :: !Bool
  -- ^ Whether the manifest named the identifier; Android keeps its own
  -- package naming otherwise.
  }
  deriving stock (Eq, Show)

{-| A value the `[app]` table holds that cannot be built: its key, its line
    and why. -}
data IdentityProblem = IdentityProblem { problemKey :: !Text, problemLine :: !Int, problemReason :: !Text }
  deriving stock (Eq, Show)

{-| The identity of an application with no `[app]` table: named `name`,
    identified as `identifier`, version 1.0 build 1, opening no links. -}
defaultIdentity :: Text -> Text -> Identity
defaultIdentity name identifier = Identity name identifier "1.0" 1 [] False

{-| The `[app]` table's entries (key, value as written, line) over the
    defaults; any value that cannot be built is a problem and an unknown key
    is one too. -}
settleIdentity :: Identity -> [(Text, Text, Int)] -> Either [IdentityProblem] Identity
settleIdentity defaults entries = case foldl step (defaults, []) entries of
  (identity, []) -> Right identity
  (_, problems) -> Left (reverse problems)
 where
  step (identity, problems) (key, raw, line) = case key of
    "name" -> checked identity problems key line (nonEmpty raw) (\value -> identity{identityName = value})
    "identifier" -> checked identity problems key line (reverseDns raw) (\value -> identity{identityIdentifier = value, identityDeclared = True})
    "version" -> checked identity problems key line (release raw) (\value -> identity{identityVersion = value})
    "build" -> checked identity problems key line (buildNumber raw) (\value -> identity{identityBuild = value})
    "schemes" -> checked identity problems key line (mapM scheme (list raw)) (\value -> identity{identitySchemes = value})
    _ -> (identity, IdentityProblem key line "no such key; the keys are name, identifier, version, build and schemes" : problems)
  checked identity problems key line answer apply = case answer of
    Right value -> (apply value, problems)
    Left reason -> (identity, IdentityProblem key line reason : problems)

nonEmpty :: Text -> Either Text Text
nonEmpty raw
  | Text.null (Text.strip (unquoted raw)) = Left "the name is empty"
  | otherwise = Right (Text.strip (unquoted raw))

-- Two or more segments of ASCII letters, digits and hyphens, each starting
-- with a letter, joined by dots.
reverseDns :: Text -> Either Text Text
reverseDns raw
  | length segments >= 2 && all segment segments = Right value
  | otherwise = Left ("\"" <> value <> "\" is not a reverse-DNS identifier such as com.example.app")
 where
  value = unquoted raw
  segments = Text.splitOn "." value
  segment part = case Text.uncons part of
    Just (first, rest) -> isLetter first && Text.all (\c -> isLetter c || isDigit c || c == '-') rest
    Nothing -> False

-- One to three dot-separated numbers.
release :: Text -> Either Text Text
release raw
  | not (null parts) && length parts <= 3 && all (\part -> not (Text.null part) && Text.all isDigit part) parts = Right value
  | otherwise = Left ("\"" <> value <> "\" is not a version such as 1.4 or 1.4.2")
 where
  value = unquoted raw
  parts = Text.splitOn "." value

buildNumber :: Text -> Either Text Int
buildNumber raw = case readMaybe (Text.unpack (unquoted raw)) of
  Just number | number >= 1 && number <= (2100000000 :: Int) -> Right number
  _ -> Left ("\"" <> unquoted raw <> "\" is not a build number: a whole number from 1 that rises with every upload")

-- A letter, then letters, digits, plus, dot and hyphen.
scheme :: Text -> Either Text Text
scheme value = case Text.uncons value of
  Just (first, rest) | isLetter first && Text.all (\c -> isLetter c || isDigit c || c `elem` ("+.-" :: String)) rest -> Right (Text.toLower value)
  _ -> Left ("\"" <> value <> "\" is not a URL scheme such as myapp")

isLetter :: Char -> Bool
isLetter c = isAsciiLower c || isAsciiUpper c

list :: Text -> [Text]
list raw = case Text.stripPrefix "[" (Text.strip raw) >>= Text.stripSuffix "]" of
  Just inner -> filter (not . Text.null) (map (unquoted . Text.strip) (Text.splitOn "," inner))
  Nothing -> [unquoted raw]

unquoted :: Text -> Text
unquoted value = case Text.stripPrefix "\"" stripped >>= Text.stripSuffix "\"" of
  Just inner -> inner
  Nothing -> case Text.stripPrefix "'" stripped >>= Text.stripSuffix "'" of
    Just inner -> inner
    Nothing -> stripped
 where
  stripped = Text.strip value
