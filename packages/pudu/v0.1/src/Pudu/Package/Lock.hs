{-| @Package.Lock — `pudu.lock`, what was chosen and what it contains

    The lock is written by `pudu install` and read by it and by the compiler.
    It is a small, fixed subset of TOML — one `[[package]]` table per package,
    string fields and one list of strings — rendered with entries sorted by name
    and fields in a fixed order, so the same graph writes the same bytes. The
    reader accepts exactly what the writer writes and says which line it could
    not read, because a lock edited by hand or cut short by a merge must be
    noticed rather than half-trusted. -}
module Pudu.Package.Lock
  ( Lock (..)
  , LockEntry (..)
  , emptyLock
  , renderLock
  , parseLock
  , lockFileName
  , findEntry
  ) where

import Data.List (sortOn)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Package.Identity (PackageId, parsePackageId, renderPackageId)

lockFileName :: FilePath
lockFileName = "pudu.lock"

data LockEntry = LockEntry
  { entryName :: !PackageId
  , entryVersion :: !Text
  , entrySource :: !Text
  , entryChecksum :: !Text
  , entryRoot :: !Text
  , entryDependencies :: ![Text]
  }
  deriving stock (Eq, Show)

newtype Lock = Lock {lockEntries :: [LockEntry]}
  deriving stock (Eq, Show)

emptyLock :: Lock
emptyLock = Lock []

findEntry :: PackageId -> Lock -> Maybe LockEntry
findEntry package (Lock entries) = case filter ((== package) . entryName) entries of
  entry : _ -> Just entry
  [] -> Nothing

renderLock :: Lock -> Text
renderLock (Lock entries) =
  Text.unlines
    ( ["# Written by pudu install. Do not edit by hand.", "version = 1"]
        <> concatMap entry (sortOn (renderPackageId . entryName) entries)
    )
 where
  entry e =
    [ ""
    , "[[package]]"
    , "name = " <> string (renderPackageId (entryName e))
    , "version = " <> string (entryVersion e)
    , "source = " <> string (entrySource e)
    , "checksum = " <> string (entryChecksum e)
    , "root = " <> string (entryRoot e)
    , "dependencies = [" <> Text.intercalate ", " (map string (entryDependencies e)) <> "]"
    ]

string :: Text -> Text
string value = "\"" <> Text.concatMap escape value <> "\""
 where
  escape '"' = "\\\""
  escape '\\' = "\\\\"
  escape c = Text.singleton c

{-| Read a lock, or the line that stops it being one. -}
parseLock :: Text -> Either Text Lock
parseLock contents = go (zip [1 :: Int ..] (Text.lines contents)) False Nothing []
 where
  go [] _ current done = Lock . reverse <$> finish current done
  go ((number, line) : rest) seenVersion current done
    | Text.null trimmed || "#" `Text.isPrefixOf` trimmed = go rest seenVersion current done
    | trimmed == "[[package]]" = do
        finished <- finish current done
        go rest seenVersion (Just []) finished
    | otherwise = case Text.breakOn "=" trimmed of
        (_, "") -> Left (at number "expected key = value")
        (rawKey, rawValue) -> do
          let key = Text.strip rawKey
              value = Text.strip (Text.drop 1 rawValue)
          case current of
            Nothing
              | key == "version" && value == "1" -> go rest True current done
              | key == "version" -> Left (at number ("this lock is version " <> value <> "; this pudu reads version 1"))
              | otherwise -> Left (at number ("unexpected " <> key <> " before the first [[package]]"))
            Just fields -> do
              parsed <- if key == "dependencies" then list number value else (: []) <$> quoted number value
              go rest seenVersion (Just ((key, parsed) : fields)) done
   where
    trimmed = Text.strip line
  finish Nothing done = Right done
  finish (Just fields) done = do
    let field key = case lookup key fields of
          Just [value] -> Right value
          _ -> Left ("a [[package]] in pudu.lock has no " <> key)
    name <- field "name" >>= parsePackageId
    version <- field "version"
    source <- field "source"
    checksum <- field "checksum"
    root <- field "root"
    let dependencies = maybe [] id (lookup "dependencies" fields)
    Right (LockEntry name version source checksum root dependencies : done)
  at number message = "pudu.lock:" <> Text.pack (show number) <> ": " <> message
  quoted number value = case Text.stripPrefix "\"" value >>= Text.stripSuffix "\"" of
    Just inner -> Right (Text.replace "\\\\" "\\" (Text.replace "\\\"" "\"" inner))
    Nothing -> Left (at number ("expected a quoted string, found " <> value))
  list number value = case Text.stripPrefix "[" value >>= Text.stripSuffix "]" of
    Just inner
      | Text.null (Text.strip inner) -> Right []
      | otherwise -> traverse (quoted number . Text.strip) (Text.splitOn "," inner)
    Nothing -> Left (at number ("expected a list of strings, found " <> value))
