{-| @Backend.Toolchain.Cache — compiled native executables reused by content.

    The C compiler is most of a native build's time, and the same generated C
    with the same flags and compiler always gives the same executable. An entry
    is keyed by everything that reaches the compiler, so a lookup finds the
    executable of exactly this input or nothing. Entries are published through
    a temporary file and a rename, so a concurrent build never reads a partial
    one, and any failure here falls back to compiling: the cache never changes
    what a build produces. -}
module Pudu.Backend.Toolchain.Cache
  ( NativeKey
  , nativeKey
  , restoreNative
  , storeNative
  ) where

import Control.Exception (IOException, onException, try)
import Control.Monad (forM_, void, when)
import Crypto.Hash (Blake2b_256, Digest, hash)
import qualified Data.ByteString as ByteString
import Data.List (isSuffixOf, sortOn)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import qualified Data.Text.Encoding.Error as Encoding
import Data.Time.Clock (getCurrentTime)
import Pudu.Cache.Location (cacheRoot, compilerIdentity, hexDigest)
import System.Directory
  ( copyFileWithMetadata
  , createDirectoryIfMissing
  , doesFileExist
  , getModificationTime
  , listDirectory
  , removeFile
  , renameFile
  , setModificationTime
  )
import Pudu.Backend.Toolchain.Process (runTool, timeoutSeconds)
import System.FilePath (takeDirectory, takeFileName, (</>))
import System.Info (arch, os)
import System.IO (hClose, openBinaryTempFile)

{-| The name of one entry: a digest of everything the compiler is given. -}
newtype NativeKey = NativeKey String

{-| How many executables are kept; storing past this removes the oldest. -}
entryLimit :: Int
entryLimit = 256

{-| The key for compiling `source` with `compiler` and `arguments`, or none
    when caching is off. The running compiler's identity fixes the embedded
    host binding sources; the C compiler's version output keeps an upgraded
    compiler from reusing its predecessor's executables. -}
nativeKey :: FilePath -> [String] -> Text -> IO (Maybe NativeKey)
nativeKey compiler arguments source = do
  root <- cacheRoot
  case root of
    Nothing -> pure Nothing
    Just _ -> do
      identity <- compilerIdentity
      version <- compilerVersion compiler
      pure $ case version of
        -- A compiler that cannot say what it is gets no entry: its build
        -- runs, and is bounded, exactly as without a cache.
        Nothing -> Nothing
        Just said ->
          let parts = map Text.pack [identity, compiler, os, arch] <> [said] <> map Text.pack arguments <> [source]
           in Just (NativeKey (hexDigest (hash (Encoding.encodeUtf8 (Text.intercalate "\0" parts)) :: Digest Blake2b_256)))

{-| Publishes the cached executable for `key` at `output` and answers the
    warnings its compile printed, or nothing when there is no such entry. -}
restoreNative :: NativeKey -> FilePath -> IO (Maybe Text)
restoreNative (NativeKey key) output = do
  root <- cacheRoot
  case root of
    Nothing -> pure Nothing
    Just base -> do
      let entry = base </> "native" </> key
      restored <- try $ do
        present <- doesFileExist entry
        if not present
          then pure Nothing
          else do
            warnings <- readWarnings (entry <> ".warnings")
            (temporary, handle) <- openBinaryTempFile (takeDirectory output) (takeFileName output <> ".pudu-cache")
            hClose handle
            (copyFileWithMetadata entry temporary >> renameFile temporary output)
              `onException` void (try @IOException (removeFile temporary))
            now <- getCurrentTime
            setModificationTime entry now
            pure (Just warnings)
      pure (either (\(_ :: IOException) -> Nothing) id restored)

{-| Keeps a copy of a freshly compiled executable and its warnings under
    `key`. The warnings are published first, so an entry a lookup finds always
    has them. -}
storeNative :: NativeKey -> FilePath -> Text -> IO ()
storeNative (NativeKey key) executable warnings = do
  root <- cacheRoot
  forM_ root $ \base -> void $ try @IOException $ do
    let directory = base </> "native"
        entry = directory </> key
    createDirectoryIfMissing True directory
    published directory (key <> ".warnings.tmp") (entry <> ".warnings") $ \temporary ->
      ByteString.writeFile temporary (Encoding.encodeUtf8 warnings)
    published directory (key <> ".tmp") entry $ \temporary -> copyFileWithMetadata executable temporary
    pruned directory

-- Writes through a temporary file in `directory`, then renames it to `target`.
published :: FilePath -> String -> FilePath -> (FilePath -> IO ()) -> IO ()
published directory template target write = do
  (temporary, handle) <- openBinaryTempFile directory template
  hClose handle
  (write temporary >> renameFile temporary target)
    `onException` void (try @IOException (removeFile temporary))

-- Removes the oldest executables beyond the limit, with their warnings.
pruned :: FilePath -> IO ()
pruned directory = do
  names <- listDirectory directory
  let executables = [name | name <- names, not (".warnings" `isSuffixOf` name), not (".tmp" `isSuffixOf` name)]
  when (length executables > entryLimit) $ do
    dated <- mapM (\name -> (,) name <$> getModificationTime (directory </> name)) executables
    forM_ (take (length executables - entryLimit) (map fst (sortOn snd dated))) $ \name -> do
      void (try @IOException (removeFile (directory </> name)))
      void (try @IOException (removeFile (directory </> name <> ".warnings")))

readWarnings :: FilePath -> IO Text
readWarnings path = do
  read' <- try (ByteString.readFile path)
  pure $ case read' of
    Right bytes -> Encoding.decodeUtf8With Encoding.lenientDecode bytes
    Left (_ :: IOException) -> Text.empty

-- What the C compiler says its version is, asked through the same bounded
-- runner as a compile, or nothing when it fails, hangs or says nothing.
compilerVersion :: FilePath -> IO (Maybe Text)
compilerVersion compiler = do
  seconds <- timeoutSeconds
  answered <- try (runTool compiler ["--version"] seconds)
  pure $ case answered of
    Right (Right said) | not (Text.null (Text.strip said)) -> Just said
    Right _ -> Nothing
    Left (_ :: IOException) -> Nothing
