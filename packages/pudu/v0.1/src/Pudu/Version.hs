module Pudu.Version
  ( versionText
  , languageConstraint
  , acceptsLanguage
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Data.Version (showVersion, versionBranch)
import qualified Paths_pudu as Package

versionText :: Text
versionText = Text.pack (showVersion Package.version)

languageConstraint :: Text
languageConstraint = ">=" <> versionText <> " <" <> nextMinor
 where
  nextMinor = case versionBranch Package.version of
    major : minor : _ -> Text.pack (show major <> "." <> show (minor + 1) <> ".0")
    major : _ -> Text.pack (show (major + 1) <> ".0.0")
    [] -> versionText

acceptsLanguage :: Text -> Either Text Bool
acceptsLanguage input
  | null clauses = Left "the language constraint is empty"
  | otherwise = and <$> traverse accepts clauses
 where
  clauses = Text.words input
  current = map toInteger (versionBranch Package.version)
  accepts clause = do
    let (operator, number) = Text.span (`elem` ("><=!" :: String)) clause
        components = Text.splitOn "." number
    wanted <- if null components || length components > 4
      then Left "a language version must contain one to four numeric components"
      else traverse component components
    let width = max (length current) (length wanted)
        pad values = take width (values <> repeat 0)
        order = compare (pad current) (pad wanted)
    case operator of
      "" -> Right (order == EQ)
      "=" -> Right (order == EQ)
      "==" -> Right (order == EQ)
      ">=" -> Right (order /= LT)
      "<=" -> Right (order /= GT)
      ">" -> Right (order == GT)
      "<" -> Right (order == LT)
      _ -> Left "unsupported language version operator"
  component value
    | Text.null value || not (Text.all (\c -> c >= '0' && c <= '9') value) =
        Left "language versions must use numeric components"
    | Text.length value > 10 = Left "language version component is too large"
    | otherwise = Right (Text.foldl' (\total c -> total * 10 + toInteger (fromEnum c - fromEnum '0')) 0 value)
