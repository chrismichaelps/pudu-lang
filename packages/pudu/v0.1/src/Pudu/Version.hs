{-# LANGUAGE TemplateHaskell #-}

module Pudu.Version
  ( versionText
  , sourceDigest
  , identityText
  , digestIn
  , languageConstraint
  , acceptsLanguage
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Data.Version (showVersion, versionBranch)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as Char8
import qualified Paths_pudu as Package
import Pudu.Version.Digest (sourceDigestLiteral)

versionText :: Text
versionText = Text.pack (showVersion Package.version)

{-| The literal the build spliced in, kept whole so its bytes stand in the
    executable exactly as `digestIn` looks for them. -}
digestLiteral :: String
digestLiteral = $(sourceDigestLiteral)

{-| The SHA-256 of the sources this compiler was built from, in hex. -}
sourceDigest :: Text
sourceDigest = Text.pack (take 64 (drop (length prefix) digestLiteral))
 where
  prefix = "PUDU-SOURCE-DIGEST:" :: String

{-| What a compiler that made checked products is called, so a runtime can
    tell whether they are its own: the version a reader sees and the digest
    that decides. -}
identityText :: Text
identityText = versionText <> "+" <> sourceDigest

{-| The source digest an executable's bytes carry, when they carry exactly one
    well-formed digest literal. Read from bytes rather than by running the file,
    since the file may be built for another platform. The prefix is assembled
    here from two pieces so this function's own needle is never itself a match. -}
digestIn :: ByteString.ByteString -> Maybe Text
digestIn bytes = go bytes
 where
  needle = Char8.pack ("PUDU-SOURCE" <> "-DIGEST:")
  go rest =
    let (_, found) = ByteString.breakSubstring needle rest
     in if ByteString.null found
          then Nothing
          else
            let candidate = ByteString.take 65 (ByteString.drop (ByteString.length needle) found)
                hex = ByteString.take 64 candidate
             in if ByteString.length candidate == 65
                  && Char8.last candidate == ';'
                  && Char8.all (\c -> (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) hex
                  then Just (Text.pack (Char8.unpack hex))
                  else go (ByteString.drop 1 found)

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
