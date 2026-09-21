{-| @Compiler.Cache.Module — keeps unchanged modules' compiled products across runs -}
module Pudu.Compiler.Cache
  ( ProductCache
  , CheckedProduct (..)
  , disabledCache
  , graphFingerprint
  , interfaceFingerprint
  , interfaceKey
  , lookupChecked
  , lookupFrontend
  , openProductCache
  , openProductCacheAt
  , pruneProducts
  , sourceFingerprint
  , storeChecked
  , storeFrontend
  ) where

import Control.Exception (IOException, try)
import Control.Monad (forM_, when)
import Crypto.Hash (Blake2b_256, Context, Digest, hash, hashFinalize, hashInit, hashUpdate)
import qualified Data.ByteArray as ByteArray
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as Char8
import Data.ByteString (ByteString)
import Data.Char (isHexDigit)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Pudu.Cache.Persist (decodeWith, encodeFor)
import qualified Data.Set as Set
import Pudu.Frontend.Syntax.Tree (Module)
import Pudu.Semantic.Interface (moduleExportKeys, moduleExports)
import Pudu.Type.Interface
  ( interfaceBindings
  , interfaceDeclarations
  , interfaceDefaults
  , interfaceImports
  , interfacePrivateDeclarations
  , interfaceSkeleton
  )
import Data.IORef (IORef, modifyIORef', newIORef, readIORef, writeIORef)
import Pudu.Source (Source, SourceName (..), Span, newSource, sourceDigest)
import Pudu.Version (versionText)
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , getFileSize
  , getHomeDirectory
  , getModificationTime
  , listDirectory
  , removeDirectoryRecursive
  , removeFile
  , renameFile
  , setModificationTime
  )
import Data.List (sortOn)
import Data.Time.Clock (UTCTime, getCurrentTime)
import System.Environment (getExecutablePath, lookupEnv)
import System.FilePath ((</>))
import System.IO (Handle, hClose, openBinaryTempFile)

{-| Where compiled products are kept between runs, or nowhere.

    Each run of the compiler used to lex, parse, and check every module it
    reached, the standard library included, although almost none of them had
    changed since the last run. A product is stored under the fingerprint of
    everything it was made from, so a lookup either finds the product of exactly
    this input or finds nothing: there is no entry that can be stale, only
    entries that are never asked for again.

    Products live in a directory named by the compiler that made them — its
    version and the size and time of its executable — so a rebuilt or upgraded
    compiler reads none of its predecessor's, and removes them. -}
data ProductCache = ProductCache
  { cacheDirectory :: !(Maybe FilePath)
  {-| A source no module is, which spans are written against when only what a
      declaration says matters and not where it was written. -}
  , cacheDetached :: !(Maybe Source)
  {-| Whether this compile stored anything, which is when pruning is due. -}
  , cacheStored :: !(Maybe (IORef Bool))
  {-| Each source's interface key, by the source's digest, as its frontend
      was produced this compile. -}
  , cacheKeys :: !(Maybe (IORef (Map ByteString ByteString)))
  }

disabledCache :: ProductCache
disabledCache = ProductCache Nothing Nothing Nothing Nothing

{-| What a module's check produced that running it needs: the tree after
    expansion and what each integer literal became. Only a module that
    compiled without a diagnostic is stored, so a diagnostic is always
    produced fresh, by the compiler that reports it. -}
data CheckedProduct = CheckedProduct
  { checkedModule :: ~Module
  , checkedIntegerKinds :: ~(Map Span Text)
  }

{-| Open the cache the environment asks for.

    `PUDU_CACHE=off` turns it off, any other value names the directory, and
    otherwise it is the user's cache directory. A cache that cannot be opened
    is no cache: compiling never depends on one. -}
openProductCache :: IO ProductCache
openProductCache = do
  requested <- lookupEnv "PUDU_CACHE"
  case requested of
    Just "off" -> pure disabledCache
    Just "" -> pure disabledCache
    Just directory -> openProductCacheAt directory
    Nothing -> do
      xdg <- lookupEnv "XDG_CACHE_HOME"
      base <- case xdg of
        Just directory | not (null directory) -> pure directory
        _ -> (</> ".cache") <$> getHomeDirectory
      openProductCacheAt (base </> "pudu")

{-| Open a cache rooted at a directory, which is created if it is missing. -}
openProductCacheAt :: FilePath -> IO ProductCache
openProductCacheAt root = do
  opened <- try $ do
    identity <- compilerIdentity
    let directory = root </> identity
    createDirectoryIfMissing True directory
    pruneOthers root identity
    pure directory
  case opened :: Either IOException FilePath of
    Right directory -> do
      detached <- newSource (SourceName "\0interface") ""
      stored <- newIORef False
      keys <- newIORef Map.empty
      pure (ProductCache (Just directory) (Just detached) (Just stored) (Just keys))
    Left _ -> pure disabledCache

{-| The compiler that is running, as a name no other build shares. -}
compilerIdentity :: IO String
compilerIdentity = do
  executable <- getExecutablePath
  size <- getFileSize executable
  modified <- getModificationTime executable
  pure $ hexDigest $ hash $ Encoding.encodeUtf8 $ Text.intercalate "\0"
    [ "pudu-cache-1"
    , versionText
    , Text.pack executable
    , Text.pack (show size)
    , Text.pack (show modified)
    ]

{-| Remove what other compilers left, which this one can never read. Only
    directories named the way this module names them are touched. -}
pruneOthers :: FilePath -> String -> IO ()
pruneOthers root identity = do
  entries <- listDirectory root
  forM_ entries $ \entry ->
    when (entry /= identity && length entry == 64 && all isHexDigit entry) $ do
      isDirectory <- doesDirectoryExist (root </> entry)
      when isDirectory $ do
        _ <- try (removeDirectoryRecursive (root </> entry)) :: IO (Either IOException ())
        pure ()

{-| A source's text, as the key its products are stored under. -}
sourceFingerprint :: Source -> ByteString
sourceFingerprint = sourceDigest

{-| Every module of a program, as one key.

    A module's check reads every interface in the program — implementations
    are visible everywhere once they exist anywhere — so a checked product is
    valid only for the program whose modules produced it. -}
graphFingerprint :: [(Text, ByteString)] -> ByteString
graphFingerprint modules =
  ByteArray.convert $ hashFinalize $ foldl step (hashInit :: HashContext) modules
 where
  step context (name, fingerprint) =
    hashUpdate (hashUpdate context (Encoding.encodeUtf8 name <> "\0")) fingerprint

type HashContext = Context Blake2b_256

{-| A parsed module, and the fingerprint of the interface it presents to the
    modules that import it. Both are functions of the text alone, so they are
    stored together and read together, and the fingerprint is read without
    reading any declaration. -}
lookupFrontend :: ProductCache -> Source -> IO (Maybe Module)
lookupFrontend cache source = do
  found <- withEntry cache (entryName "frontend" [sourceFingerprint source]) (decodeWith source)
  case found of
    Just (key, parsed) -> recordKey cache source key >> pure (Just parsed)
    Nothing -> pure Nothing

{-| Store a parse that produced no diagnostic, with its interface key. -}
storeFrontend :: ProductCache -> Source -> Module -> IO ()
storeFrontend cache source parsed = case interfaceFingerprint cache parsed of
  Nothing -> pure ()
  Just key -> do
    recordKey cache source key
    writeEntry cache (entryName "frontend" [sourceFingerprint source]) (encodeFor source (key, parsed))

recordKey :: ProductCache -> Source -> ByteString -> IO ()
recordKey cache source key =
  mapM_ (\keys -> modifyIORef' keys (Map.insert (sourceFingerprint source) key)) (cacheKeys cache)

{-| The key a module presents to the modules importing it, or its whole text
    when its interface was never formed — a module that did not parse cleanly
    is keyed by everything it says. -}
interfaceKey :: ProductCache -> Source -> IO ByteString
interfaceKey cache source = case cacheKeys cache of
  Nothing -> pure (sourceFingerprint source)
  Just keys -> Map.findWithDefault (sourceFingerprint source) (sourceFingerprint source) <$> readIORef keys

{-| What another module can observe of this one, as a key: its imports, its
    body-free exported declarations and private type shells, the constants it
    exports and their annotations, which trait members have defaults, and every
    name it exports.

    Positions are left out — every span is written against a source no module
    has — so moving a declaration, or editing any function's body, leaves the
    key where it was, and the checked products of every other module stay
    reusable. A change another module could see changes the key. -}
interfaceFingerprint :: ProductCache -> Module -> Maybe ByteString
interfaceFingerprint cache parsed = against <$> cacheDetached cache
 where
  skeleton = interfaceSkeleton parsed
  against detached =
    let encoded = encodeFor detached
          ( ( interfaceImports skeleton
            , interfaceDeclarations skeleton
            )
          , ( interfacePrivateDeclarations skeleton
            , interfaceBindings skeleton
            )
          )
        described = Encoding.encodeUtf8 $ Text.pack $ show
          ( Set.toList (interfaceDefaults skeleton)
          , moduleExportKeys (moduleExports parsed)
          )
     in ByteArray.convert (hash (encoded <> "\0" <> described) :: Digest Blake2b_256)

lookupChecked :: ProductCache -> ByteString -> Source -> IO (Maybe CheckedProduct)
lookupChecked cache graph source =
  withEntry cache (entryName "checked" [graph, sourceFingerprint source]) $ \bytes ->
    {-| Read only when used. The entry's digest was checked before this runs,
        so what is read is what was written by this compiler. A check never
        reads the tree it would run; a run reads it as it loads. -}
    let decoded = case decodeWith source bytes of
          Just value -> value
          Nothing -> error "pudu: a stored module could not be read; run with PUDU_CACHE=off"
     in Just (CheckedProduct (fst decoded) (Map.fromList (snd decoded)))

storeChecked :: ProductCache -> ByteString -> Source -> CheckedProduct -> IO ()
storeChecked cache graph source stored =
  writeEntry cache (entryName "checked" [graph, sourceFingerprint source])
    (encodeFor source (checkedModule stored, Map.toList (checkedIntegerKinds stored)))

entryName :: Text -> [ByteString] -> String
entryName kind parts =
  hexDigest (hash (ByteString.concat (Encoding.encodeUtf8 kind : "\0" : parts)) :: Digest Blake2b_256)

{-| The stored payload followed by its own digest: a file cut short, written
    by a crashed run, or damaged on disk fails the comparison and is a miss. -}
withEntry :: ProductCache -> String -> (ByteString -> Maybe a) -> IO (Maybe a)
withEntry cache name decode = case cacheDirectory cache of
  Nothing -> pure Nothing
  Just directory -> do
    let path = directory </> name
    loaded <- try (ByteString.readFile path)
    case verified loaded >>= decode of
      Nothing -> pure Nothing
      found -> do
        {-| Reading an entry marks it used, so pruning removes what nothing
            has asked for rather than what was written first. -}
        now <- getCurrentTime
        _ <- try (setModificationTime path now) :: IO (Either IOException ())
        pure found
 where
  verified :: Either IOException ByteString -> Maybe ByteString
  verified loaded = case loaded of
    Right bytes | ByteString.length bytes >= digestSize ->
      let (payload, digest) = ByteString.splitAt (ByteString.length bytes - digestSize) bytes
       in if digest == checksum payload then Just payload else Nothing
    _ -> Nothing

{-| Written beside its final name and renamed into place, so a reader sees a
    whole entry or none, however many compilers write at once. -}
writeEntry :: ProductCache -> String -> ByteString -> IO ()
writeEntry cache name payload = case cacheDirectory cache of
  Nothing -> pure ()
  Just directory -> do
    opened <- try (openBinaryTempFile directory (name <> ".tmp"))
    case opened :: Either IOException (FilePath, Handle) of
      Left _ -> pure ()
      Right (temporary, handle) -> do
        written <- try $ do
          ByteString.hPut handle payload
          ByteString.hPut handle (checksum payload)
          hClose handle
          renameFile temporary (directory </> name)
        case written :: Either IOException () of
          Right () -> mapM_ (`writeIORef` True) (cacheStored cache)
          Left _ -> do
            _ <- try (hClose handle) :: IO (Either IOException ())
            _ <- try (removeFile temporary) :: IO (Either IOException ())
            pure ()

{-| Keep the cache to a bounded number of entries, removing the least recently
    used first.

    Every edit to a module stores new products under new keys and the old ones
    are never asked for again, so without a bound the directory grows for as
    long as anyone edits. Run after a compile that stored something; a compile
    that only read never grows the cache. -}
pruneProducts :: ProductCache -> IO ()
pruneProducts cache = case (cacheDirectory cache, cacheStored cache) of
  (Just directory, Just stored) -> do
    wrote <- readIORef stored
    when wrote (pruneIn directory)
  _ -> pure ()
 where
  pruneIn directory = do
    listed <- try (listDirectory directory)
    case listed :: Either IOException [FilePath] of
      Left _ -> pure ()
      Right entries -> when (length entries > entryLimit) $ do
        dated <- mapM (dateOf directory) entries
        let known = sortOn snd [(entry, time) | (entry, Just time) <- dated]
        forM_ (take (length known - entryLimit `div` 2) known) $ \(entry, _) -> do
          _ <- try (removeFile (directory </> entry)) :: IO (Either IOException ())
          pure ()
  dateOf directory entry = do
    dated <- try (getModificationTime (directory </> entry))
    pure (entry, either (const Nothing) Just (dated :: Either IOException UTCTime))

{-| About forty megabytes at the size a standard-library module's products
    take; halved when exceeded, so pruning is rare. -}
entryLimit :: Int
entryLimit = 4096

checksum :: ByteString -> ByteString
checksum payload = ByteArray.convert (hash payload :: Digest Blake2b_256)

digestSize :: Int
digestSize = 32

hexDigest :: Digest Blake2b_256 -> String
hexDigest = Char8.unpack . ByteArray.convert . toHex
 where
  toHex digest = ByteString.concatMap byteHex (ByteArray.convert digest)
  byteHex value =
    let (high, low) = value `divMod` 16
     in ByteString.pack [hexChar high, hexChar low]
  hexChar nibble
    | nibble < 10 = 48 + nibble
    | otherwise = 87 + nibble
