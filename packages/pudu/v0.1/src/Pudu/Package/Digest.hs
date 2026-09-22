{-| @Package.Digest — what a package's content is, as one line a lock can hold

    A release archive is checked by the digest of its bytes. A directory — an
    installed package, a git checkout — is checked by its tree digest: the
    SHA-256 of its sorted listing, one line per file giving its path, its size,
    and the digest of its content. The listing is built from the files alone,
    never from times or permissions, so the same files give the same digest on
    every machine. -}
module Pudu.Package.Digest
  ( sha256Hex
  , treeDigest
  , treeFiles
  , copyTree
  , TreeProblem (..)
  , renderTreeProblem
  ) where

import Control.Monad (forM, forM_, when)
import qualified Crypto.Hash as Hash
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as Char8
import Data.List (sort)
import Data.Text (Text)
import qualified Data.Text as Text
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , listDirectory
  , pathIsSymbolicLink
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
      lines' <- forM files $ \relative -> do
        content <- ByteString.readFile (root </> relative)
        pure
          ( Char8.pack (slashed relative) <> "\0"
              <> Char8.pack (show (ByteString.length content)) <> "\0"
              <> encodeText (sha256Hex content) <> "\n"
          )
      pure (Right ("sha256:" <> sha256Hex (ByteString.concat lines')))
 where
  encodeText = Char8.pack . Text.unpack

{-| The listing uses forward slashes on every system, so a digest taken on one
    machine is the digest on another. -}
slashed :: FilePath -> String
slashed path = foldr1 (\a b -> a <> "/" <> b) (splitDirectories path)

{-| Copy a package's files into a destination, the same files `treeFiles` names. -}
copyTree :: FilePath -> FilePath -> IO (Either TreeProblem ())
copyTree from to = do
  listed <- treeFiles from
  case listed of
    Left problem -> pure (Left problem)
    Right files -> do
      createDirectoryIfMissing True to
      forM_ files $ \relative -> do
        let target = to </> relative
        createDirectoryIfMissing True (takeDirectory target)
        content <- ByteString.readFile (from </> relative)
        ByteString.writeFile target content
      when (null files) (createDirectoryIfMissing True to)
      pure (Right ())
