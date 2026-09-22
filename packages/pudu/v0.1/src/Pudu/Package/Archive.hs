{-| @Package.Archive — a package's files as a `.tar.gz`, and back

    `packDirectory` writes the files `Digest.treeFiles` lists as a USTAR
    archive with mode 0644, owner 0, and modification time 0, sorted by path,
    then gzips it at level 9. The same files always give the same bytes.

    `unpackArchive` decompresses within `unpackedLimit`, reads the tar stream,
    and refuses: an entry type other than a regular file or directory, an
    absolute path, an empty, `.`, or `..` segment, a backslash or NUL, a path
    over 255 bytes, a path given twice, and more than `fileLimit` files.
    Files are written under a staging directory renamed into place, so a
    refused archive leaves nothing at the destination. -}
module Pudu.Package.Archive
  ( packDirectory
  , unpackArchive
  , archiveEntries
  , unpackedLimit
  , fileLimit
  ) where

import Control.Monad (forM, forM_, when)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as Char8
import Data.Char (isDigit)
import Data.List (group, sort)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Pudu.Eval.Compress (compressGzip, decompressGzip)
import Pudu.Eval.Io (IoOutcome (..))
import Pudu.Package.Digest (renderTreeProblem, treeFiles)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, removeDirectoryRecursive, renameDirectory)
import System.FilePath (splitDirectories, takeDirectory, (</>))

{-| Largest unpacked archive, in bytes: 64 MiB. -}
unpackedLimit :: Integer
unpackedLimit = 67108864

{-| Largest number of files in one archive. -}
fileLimit :: Int
fileLimit = 5000

pathLimit :: Int
pathLimit = 255

{-| The gzipped USTAR archive of a directory's package files. -}
packDirectory :: FilePath -> IO (Either Text ByteString.ByteString)
packDirectory root = do
  listed <- treeFiles root
  case listed of
    Left problem -> pure (Left (renderTreeProblem problem))
    Right files -> do
      entries <- forM files $ \relative -> do
        content <- ByteString.readFile (root </> relative)
        pure (slashed relative, content)
      case traverse (uncurry entryBytes) entries of
        Left problem -> pure (Left problem)
        Right blocks -> do
          let tarred = ByteString.concat blocks <> ByteString.replicate 1024 0
          compressed <- compressGzip tarred 9 65535
          pure $ case compressed of
            IoDone bytes -> Right bytes
            IoFailed problem -> Left ("cannot compress the archive: " <> problem)

slashed :: FilePath -> Text
slashed = Text.intercalate "/" . map Text.pack . splitDirectories

entryBytes :: Text -> ByteString.ByteString -> Either Text ByteString.ByteString
entryBytes path content = do
  (prefix, name) <- splitPath path
  let size = ByteString.length content
      field width value = ByteString.take width (value <> ByteString.replicate width 0)
      octal width value = let digits = Char8.pack (showOctal value) in Char8.replicate (width - 1 - ByteString.length digits) '0' <> digits <> "\0"
      unsummed =
        ByteString.concat
          [ field 100 name
          , octal 8 0o644
          , octal 8 0
          , octal 8 0
          , octal 12 size
          , octal 12 0
          , "        "
          , "0"
          , field 100 ""
          , "ustar\0"
          , "00"
          , field 32 ""
          , field 32 ""
          , octal 8 0
          , octal 8 0
          , field 155 prefix
          , ByteString.replicate 12 0
          ]
      checksum = sum (map fromIntegral (ByteString.unpack unsummed)) :: Int
      header = ByteString.take 148 unsummed <> octal 7 checksum <> " " <> ByteString.drop 156 unsummed
      padding = (512 - size `mod` 512) `mod` 512
  Right (header <> content <> ByteString.replicate padding 0)

showOctal :: Int -> String
showOctal 0 = "0"
showOctal n = go n ""
 where
  go 0 acc = acc
  go m acc = go (m `div` 8) (toEnum (fromEnum '0' + m `mod` 8) : acc)

{-| A path as the USTAR prefix and name: unchanged within 100 bytes, otherwise
    split at the last `/` leaving a name of at most 100 and a prefix of at most
    155 bytes. -}
splitPath :: Text -> Either Text (ByteString.ByteString, ByteString.ByteString)
splitPath path
  | ByteString.length whole <= 100 = Right ("", whole)
  | otherwise = case [(p, n) | i <- reverse [1 .. length parts - 1], let p = joined (take i parts), let n = joined (drop i parts), ByteString.length n <= 100, ByteString.length p <= 155] of
      found : _ -> Right found
      [] -> Left (path <> " is too long for an archive")
 where
  whole = TextEncoding.encodeUtf8 path
  parts = Text.splitOn "/" path
  joined = TextEncoding.encodeUtf8 . Text.intercalate "/"

{-| The files of a gzipped tar archive, by path, after every refusal. -}
archiveEntries :: ByteString.ByteString -> IO (Either Text [(Text, ByteString.ByteString)])
archiveEntries archive = do
  inflated <- decompressGzip archive unpackedLimit
  pure $ case inflated of
    IoFailed problem -> Left ("the archive is not gzip data within " <> Text.pack (show unpackedLimit) <> " bytes: " <> problem)
    IoDone tarred -> readEntries tarred

readEntries :: ByteString.ByteString -> Either Text [(Text, ByteString.ByteString)]
readEntries = go Set.empty []
 where
  go seen acc bytes
    | ByteString.length bytes < 512 = Left "the archive is not a complete tar stream"
    | ByteString.all (== 0) (ByteString.take 512 bytes) = Right (reverse acc)
    | otherwise = do
        let header = ByteString.take 512 bytes
            text from width = ByteString.takeWhile (/= 0) (ByteString.take width (ByteString.drop from header))
            number from width = parseOctal (text from width)
            recorded = number 148 8
            actual = sum [if i >= 148 && i < 156 then 32 else fromIntegral b | (i, b) <- zip [0 :: Int ..] (ByteString.unpack header)]
            ustar = ByteString.take 5 (ByteString.drop 257 header) == "ustar"
            prefix = if ustar then text 345 155 else ""
            name = text 0 100
            rawPath = if ByteString.null prefix then name else prefix <> "/" <> name
            kind = ByteString.index header 156
        when (recorded /= Just actual) (Left "a tar header has a wrong checksum")
        size <- maybe (Left "a tar header has no size") Right (number 124 12)
        path <- either (const (Left "a path in the archive is not UTF-8")) Right (TextEncoding.decodeUtf8' rawPath)
        let payload = ByteString.take size (ByteString.drop 512 bytes)
            next = ByteString.drop (512 + size + (512 - size `mod` 512) `mod` 512) bytes
        when (ByteString.length payload < size) (Left "the archive ends inside a file")
        case toEnum (fromIntegral kind) :: Char of
          '5' -> go seen acc next
          c | c == '0' || c == '\0' -> do
            checkPath path
            when (Set.member path seen) (Left (path <> " appears twice in the archive"))
            when (Set.size seen >= fileLimit) (Left ("the archive holds more than " <> Text.pack (show fileLimit) <> " files"))
            go (Set.insert path seen) ((path, payload) : acc) next
          '2' -> Left (path <> " is a symbolic link; a package holds only files and directories")
          '1' -> Left (path <> " is a hard link; a package holds only files and directories")
          _ -> Left (path <> " is neither a file nor a directory")
  parseOctal field =
    let digits = Char8.unpack (Char8.strip field)
     in if not (null digits) && all (\c -> isDigit c && c < '8') digits then Just (foldl (\n c -> n * 8 + fromEnum c - fromEnum '0') 0 digits) else Nothing

checkPath :: Text -> Either Text ()
checkPath path
  | Text.null path = Left "an entry has an empty path"
  | ByteString.length (TextEncoding.encodeUtf8 path) > pathLimit = Left (path <> " is longer than 255 bytes")
  | "/" `Text.isPrefixOf` path = Left (path <> " is an absolute path")
  | Text.any (`elem` ("\\\0" :: String)) path = Left (path <> " contains a backslash or NUL")
  | any (`elem` ["", ".", ".."]) (Text.splitOn "/" path) = Left (path <> " is not a plain relative path")
  | otherwise = Right ()

{-| Unpack an archive into a directory that must not exist yet. -}
unpackArchive :: ByteString.ByteString -> FilePath -> IO (Either Text ())
unpackArchive archive destination = do
  entries <- archiveEntries archive
  case entries of
    Left problem -> pure (Left problem)
    Right files -> do
      let staging = destination <> ".partial"
      leftover <- doesDirectoryExist staging
      when leftover (removeDirectoryRecursive staging)
      createDirectoryIfMissing True staging
      let directories = map (takeDirectory . (staging </>) . Text.unpack . fst) files
      mapM_ (createDirectoryIfMissing True) (map head' (group (sort directories)))
      forM_ files $ \(path, content) -> ByteString.writeFile (staging </> Text.unpack path) content
      renameDirectory staging destination
      pure (Right ())
 where
  head' = foldr const ""
