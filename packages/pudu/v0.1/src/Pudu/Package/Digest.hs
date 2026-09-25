{-| @Package.Digest — what a package's content is, as one line a lock can hold

    A release archive is checked by the digest of its bytes. A directory — an
    installed package, a git checkout — is checked by its tree digest: the
    SHA-256 of its sorted listing, one line per file giving its path, its size,
    and the digest of its content. The listing is built from the files alone,
    never from times or permissions, so the same files give the same digest on
    every machine.

    `copyTree` returns the digest of the bytes it writes, `cachedTreeDigest`
    stores the digest of an immutable directory beside it, and
    `treeFingerprint` summarises paths, sizes, and modification times without
    reading file contents. -}
module Pudu.Package.Digest
  ( sha256Hex
  , treeDigest
  , treeFiles
  , treeFingerprint
  , cachedTreeDigest
  , copyTree
  , TreeProblem (..)
  , renderTreeProblem
  ) where

import Control.Exception (IOException, try)
import Control.Monad (forM, when)
import qualified Crypto.Hash as Hash
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as Char8
import Data.List (group, sort)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Data.Time.Clock.POSIX (utcTimeToPOSIXSeconds)
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , getFileSize
  , getModificationTime
  , listDirectory
  , pathIsSymbolicLink
  , renameFile
  )
import System.FilePath (makeRelative, splitDirectories, takeDirectory, (</>))

sha256Hex :: ByteString.ByteString -> Text
sha256Hex bytes = Text.pack (show (Hash.hash bytes :: Hash.Digest Hash.SHA256))

data TreeProblem
  = LinkInTree !FilePath
  deriving stock (Eq, Show)

renderTreeProblem :: TreeProblem -> Text
renderTreeProblem (LinkInTree path) =
  Text.pack path <> " is a symbolic link; a package holds only regular files and directories"

{-| The files a package contributes, relative to its root, sorted.

    Version-control metadata, the package's own `deps/`, and anything whose name
    starts with a dot are not part of a package: they differ between checkouts
    of the same code. A symbolic link is refused rather than followed, because
    following one reads whatever it points at, inside the project or not. -}
treeFiles :: FilePath -> IO (Either TreeProblem [FilePath])
treeFiles root = fmap (fmap sort) (walk root)
 where
  walk directory = do
    names <- sort <$> listDirectory directory
    results <- forM (filter kept names) $ \name -> do
      let path = directory </> name
      link <- pathIsSymbolicLink path
      if link
        then pure (Left (LinkInTree (makeRelative root path)))
        else do
          isDirectory <- doesDirectoryExist path
          if isDirectory
            then if directory == root && name == "deps" then pure (Right []) else walk path
            else pure (Right [makeRelative root path])
    pure (concat <$> sequence results)
  kept name = not ("." `isPrefixOfString` name)
  isPrefixOfString prefix name = take (length prefix) name == prefix

{-| The tree digest of a directory, as `sha256:<hex>`. -}
treeDigest :: FilePath -> IO (Either TreeProblem Text)
treeDigest root = do
  listed <- treeFiles root
  case listed of
    Left problem -> pure (Left problem)
    Right files -> do
      lines' <- forM files $ \relative -> listingLine relative <$> ByteString.readFile (root </> relative)
      pure (Right (digestOf lines'))

listingLine :: FilePath -> ByteString.ByteString -> ByteString.ByteString
listingLine relative content =
  Char8.pack (slashed relative) <> "\0"
    <> Char8.pack (show (ByteString.length content)) <> "\0"
    <> Char8.pack (Text.unpack (sha256Hex content)) <> "\n"

digestOf :: [ByteString.ByteString] -> Text
digestOf lines' = "sha256:" <> sha256Hex (ByteString.concat lines')

{-| SHA-256 of the sorted listing `<path> NUL <size> NUL <mtime> LF`, as
    `sha256:<hex>`. File contents are not read. -}
treeFingerprint :: FilePath -> IO (Either TreeProblem Text)
treeFingerprint root = do
  listed <- treeFiles root
  case listed of
    Left problem -> pure (Left problem)
    Right files -> do
      lines' <- forM files $ \relative -> do
        size <- getFileSize (root </> relative)
        modified <- getModificationTime (root </> relative)
        pure
          ( Char8.pack (slashed relative) <> "\0" <> Char8.pack (show size) <> "\0"
              <> Char8.pack (show (utcTimeToPOSIXSeconds modified)) <> "\n"
          )
      pure (Right (digestOf lines'))

{-| The tree digest of a directory that is not modified after creation,
    read from `<directory>.digest` when present and written there otherwise. -}
cachedTreeDigest :: FilePath -> IO (Either TreeProblem Text)
cachedTreeDigest directory = do
  let sidecar = directory <> ".digest"
  stored <- try (TextIO.readFile sidecar) :: IO (Either IOException Text)
  case fmap Text.strip stored of
    Right value | "sha256:" `Text.isPrefixOf` value -> pure (Right value)
    _ -> do
      computed <- treeDigest directory
      case computed of
        Left problem -> pure (Left problem)
        Right value -> do
          TextIO.writeFile (sidecar <> ".partial") (value <> "\n")
          renameFile (sidecar <> ".partial") sidecar
          pure (Right value)

{-| The listing uses forward slashes on every system, so a digest taken on one
    machine is the digest on another. -}
slashed :: FilePath -> String
slashed path = foldr1 (\a b -> a <> "/" <> b) (splitDirectories path)

{-| Copy the files `treeFiles` lists from one directory to another and
    return the tree digest of the copied bytes. -}
copyTree :: FilePath -> FilePath -> IO (Either TreeProblem Text)
copyTree from to = do
  listed <- treeFiles from
  case listed of
    Left problem -> pure (Left problem)
    Right files -> do
      mapM_ (createDirectoryIfMissing True . (to </>)) (nubSorted (map takeDirectory files))
      lines' <- forM files $ \relative -> do
        let target = to </> relative
        content <- ByteString.readFile (from </> relative)
        ByteString.writeFile target content
        pure (listingLine relative content)
      when (null files) (createDirectoryIfMissing True to)
      pure (Right (digestOf lines'))
 where
  nubSorted = concatMap (take 1) . group . sort
