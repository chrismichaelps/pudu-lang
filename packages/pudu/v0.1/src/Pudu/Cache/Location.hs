{-| @Cache.Location — where this compiler keeps what it reuses between runs.

    Shared by the product cache and the native build cache, so both honour the
    same `PUDU_CACHE` setting and are named by the same compiler identity. -}
module Pudu.Cache.Location
  ( cacheRoot
  , compilerIdentity
  , hexDigest
  ) where

import Crypto.Hash (Blake2b_256, Digest, hash)
import qualified Data.ByteArray as ByteArray
import qualified Data.ByteString as ByteString
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Numeric (showHex)
import Pudu.Version (versionText)
import System.Directory (getFileSize, getHomeDirectory, getModificationTime)
import System.Environment (getExecutablePath, lookupEnv)
import System.FilePath ((</>))

{-| The directory every cache lives under, or none when `PUDU_CACHE` is `off`
    or empty. Another value names the directory; otherwise it is the user's
    cache directory. -}
cacheRoot :: IO (Maybe FilePath)
cacheRoot = do
  requested <- lookupEnv "PUDU_CACHE"
  case requested of
    Just "off" -> pure Nothing
    Just "" -> pure Nothing
    Just directory -> pure (Just directory)
    Nothing -> do
      xdg <- lookupEnv "XDG_CACHE_HOME"
      base <- case xdg of
        Just directory | not (null directory) -> pure directory
        _ -> (</> ".cache") <$> getHomeDirectory
      pure (Just (base </> "pudu"))

{-| The compiler that is running, as a name no other build shares: its version
    and the path, size and time of its executable. A rebuilt compiler, and so
    every source embedded in it, gets a new name. -}
compilerIdentity :: IO String
compilerIdentity = do
  executable <- getExecutablePath
  size <- getFileSize executable
  modified <- getModificationTime executable
  pure $ hexDigest $ hash $ Encoding.encodeUtf8 $ Text.intercalate "\0"
    [ "pudu-cache-2"
    , versionText
    , Text.pack executable
    , Text.pack (show size)
    , Text.pack (show modified)
    ]

{-| A digest as lowercase hexadecimal, two digits per byte. -}
hexDigest :: Digest Blake2b_256 -> String
hexDigest digest = concatMap byte (ByteString.unpack (ByteArray.convert digest))
 where
  byte value = let digits = showHex value "" in if length digits == 1 then '0' : digits else digits
