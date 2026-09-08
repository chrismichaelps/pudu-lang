{-| @Bundle — a program and its compiler in one file

    A Pudu program runs by being compiled and evaluated, which means shipping
    one means shipping its source and something able to run it. Every
    deployment target expects a single artefact instead: a file to copy into an
    image, upload as a function, or hand to someone.

    A bundle is that file. The compiler's own executable is copied, the
    program's modules are appended to the copy, and a trailer at the very end
    says where they start. Run it and it finds its own modules and runs them;
    nothing else needs to be installed, and no path on the building machine is
    referred to.

    This is not native code generation. The program is still compiled and
    interpreted, every time it starts, at the speed the evaluator runs — what
    the bundle removes is the installation, not the interpretation. The two are
    separate problems and this is the one that stops a program being deployed
    at all.

    Appending rather than embedding at link time is what lets the same
    compiler build a bundle without being rebuilt. The operating system loads
    an executable by its header and ignores what follows the segments it names,
    so extra bytes at the end are simply not read — which is why this works on
    every platform that runs the compiler.

    Every module the program reached is included, the standard library among
    them: what is bundled is what was compiled, so a bundle cannot meet a
    different `Std` from the one it was checked against. -}
module Pudu.Bundle
  ( Bundle (..)
  , bundleOf
  , writeBundled
  , attachedBundle
  , materialise
  ) where

import Control.Exception (IOException, try)
import Control.Monad (forM_, unless)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as Char8
import Data.List (sortOn)
import Data.Char (isAlpha, isAlphaNum)
import qualified Data.Set as Set
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameText)
import Pudu.Source (Source, sourceText)
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  , getPermissions
  , setOwnerExecutable
  , setPermissions
  )
import System.Environment (getExecutablePath)
import System.FilePath (joinPath, takeDirectory, (</>))
import System.IO (IOMode (ReadMode), SeekMode (AbsoluteSeek), hFileSize, hSeek, withBinaryFile)

{-| A program's modules, and which of them to start. -}
data Bundle = Bundle
  { bundleEntry :: !Text
  , bundleModules :: ![(Text, Text)]
  }
  deriving stock (Eq, Show)

{-| The marker that says a bundle is attached.

    At the very end of the file, so finding one is a read of the last few bytes
    rather than a scan. An executable that has none simply does not end with
    it, and nothing else about the file has to be understood to tell. -}
marker :: ByteString.ByteString
marker = Char8.pack "\n--pudu-bundle--\n"

{-| How many decimal digits the length before the marker occupies. -}
lengthWidth :: Int
lengthWidth = 16

{-| The bundle for a compiled program.

    Modules are ordered by name so that building the same program twice
    produces the same bytes — a build that differed run to run would defeat
    anything comparing two deployments. -}
bundleOf :: ModuleName -> Map ModuleName Source -> Bundle
bundleOf entry sources =
  Bundle
    { bundleEntry = moduleNameText entry
    , bundleModules =
        sortOn fst
          [ (moduleNameText name, sourceText source)
          | (name, source) <- Map.toList sources
          ]
    }

encode :: Bundle -> ByteString.ByteString
encode bundle =
  ByteString.concat
    ( [utf8 (bundleEntry bundle), newline, utf8 (countText (length (bundleModules bundle))), newline]
        <> concatMap one (bundleModules bundle)
    )
 where
  one (name, text) =
    let body = utf8 text
     in [ utf8 name
        , newline
        , utf8 (countText (ByteString.length body))
        , newline
        , body
        ]
  newline = Char8.pack "\n"
  countText = Text.pack . show

decode :: ByteString.ByteString -> Maybe Bundle
decode raw = do
  (entry, afterEntry) <- line raw
  (countLine, afterCount) <- line afterEntry
  count <- readNumber countLine
  (modules, _) <- take' count afterCount
  pure (Bundle (Encoding.decodeUtf8Lenient entry) modules)
 where
  line input = case ByteString.elemIndex 10 input of
    Nothing -> Nothing
    Just at -> Just (ByteString.take at input, ByteString.drop (at + 1) input)
  take' 0 input = Just ([], input)
  take' remaining input = do
    (name, afterName) <- line input
    (sizeLine, afterSize) <- line afterName
    size <- readNumber sizeLine
    unless (ByteString.length afterSize >= size) Nothing
    let body = ByteString.take size afterSize
    (rest, leftover) <- take' (remaining - 1 :: Int) (ByteString.drop size afterSize)
    pure ((Encoding.decodeUtf8Lenient name, Encoding.decodeUtf8Lenient body) : rest, leftover)
  readNumber input = case Char8.readInt input of
    Just (value, remainder) | ByteString.null remainder -> Just value
    _ -> Nothing

utf8 :: Text -> ByteString.ByteString
utf8 = Encoding.encodeUtf8

{-| Write a copy of the running compiler with a program attached to it. -}
writeBundled :: FilePath -> Bundle -> IO ()
writeBundled target bundle = do
  self <- getExecutablePath
  compiler <- ByteString.readFile self
  let body = encode bundle
      size = Text.pack (show (ByteString.length body))
      padded = Text.replicate (lengthWidth - Text.length size) "0" <> size
  ByteString.writeFile target (ByteString.concat [compiler, body, utf8 padded, marker])
  permissions <- getPermissions target
  setPermissions target (setOwnerExecutable True permissions)

{-| The bundle attached to the running executable, if there is one. -}
attachedBundle :: IO (Maybe Bundle)
attachedBundle = do
  self <- getExecutablePath
  found <- try (readTrailer self) :: IO (Either IOException (Maybe Bundle))
  pure (either (const Nothing) id found)

readTrailer :: FilePath -> IO (Maybe Bundle)
readTrailer self = withBinaryFile self ReadMode $ \handle -> do
  total <- hFileSize handle
  let trailer = toInteger (ByteString.length marker + lengthWidth)
  if total < trailer
    then pure Nothing
    else do
      hSeek handle AbsoluteSeek (total - trailer)
      tail' <- ByteString.hGet handle (fromInteger trailer)
      let (sizeText, found) = ByteString.splitAt lengthWidth tail'
      if found /= marker
        then pure Nothing
        else case Char8.readInt (Char8.dropWhile (== '0') sizeText) of
          Nothing -> pure Nothing
          Just (size, _) -> do
            hSeek handle AbsoluteSeek (total - trailer - toInteger size)
            body <- ByteString.hGet handle size
            pure (decode body)

{-| Write a bundle's modules under a directory, each at the path its name
    implies, and answer the entry module's file.

    Laid out on disk rather than resolved in memory because a module's location
    is part of how the compiler checks it: a file that is not at the path its
    name implies is a diagnostic, and a bundle that skipped the layout would be
    checked by a different rule than the program it was built from. -}
materialise :: FilePath -> Bundle -> IO FilePath
materialise root bundle = do
  let names = map fst (bundleModules bundle)
      validName name = all validSegment (Text.splitOn "." name)
      validSegment segment = case Text.uncons segment of
        Just (first, rest) -> (isAlpha first || first == '_')
          && Text.all (\character -> isAlphaNum character || character == '_') rest
        Nothing -> False
  unless (validName (bundleEntry bundle) && all validName names) $
    ioError (userError "bundle contains an invalid module name")
  unless (Set.size (Set.fromList names) == length names) $
    ioError (userError "bundle contains duplicate module names")
  unless (bundleEntry bundle `elem` names) $
    ioError (userError "bundle entry module is missing")
  forM_ (bundleModules bundle) $ \(name, text) -> do
    let path = root </> pathOfName name
    createDirectoryIfMissing True (takeDirectory path)
    present <- doesFileExist path
    unless present (ByteString.writeFile path (utf8 text))
  pure (root </> pathOfName (bundleEntry bundle))

pathOfName :: Text -> FilePath
pathOfName name = joinPath (map Text.unpack (Text.splitOn "." name)) <> ".pudu"
