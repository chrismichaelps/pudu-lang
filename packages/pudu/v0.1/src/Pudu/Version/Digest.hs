{-# LANGUAGE TemplateHaskell #-}

{-| @Version.Digest — what the compiler was built from, as one number

    Products a compiler checked can be reused only by a runtime that would check
    them the same way, and a version string cannot say that: two builds of one
    version may differ in any line of the compiler. What does say it is the
    compiler's own sources. This digest is taken over them while the compiler
    is being compiled — every Haskell module under `src`, the C and Objective-C
    under `cbits`, and the package description — so two executables share it
    exactly when they were built from the same text, whatever machine, C
    library, or architecture built them.

    It is spliced in as a single literal with a fixed prefix, so it can be read
    back out of an executable's bytes without running it: a build for another
    platform attaches to a runtime it cannot execute. -}
module Pudu.Version.Digest
  ( sourceDigestLiteral
  ) where

import Control.Monad (forM, filterM)
import qualified Crypto.Hash as Hash
import qualified Data.ByteArray.Encoding as Encoding
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as Char8
import Data.List (isSuffixOf, sort)
import Language.Haskell.TH (Exp, Q, runIO)
import Language.Haskell.TH.Syntax (Lift (lift), addDependentFile, makeRelativeToProject)
import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath ((</>))

{-| The digest literal, `PUDU-SOURCE-DIGEST:` followed by 64 lowercase hex
    digits and `;`. Every file read is declared a dependency, so editing any of
    them compiles this module again and the digest cannot go stale. -}
sourceDigestLiteral :: Q Exp
sourceDigestLiteral = do
  root <- makeRelativeToProject "."
  files <- runIO (sourceFiles root)
  mapM_ addDependentFile files
  contents <- runIO (forM files ByteString.readFile)
  let relative = map (drop (length root + 1)) files
      framed =
        mconcat
          [ Char8.pack (name <> "\0" <> show (ByteString.length body) <> "\0") <> body
          | (name, body) <- zip relative contents
          ]
      digest = Hash.hashWith Hash.SHA256 framed
      hex = Char8.unpack (Encoding.convertToBase Encoding.Base16 digest)
  lift ("PUDU-SOURCE-DIGEST:" <> hex <> ";")

{-| Every file the compiler is built from, in a fixed order. -}
sourceFiles :: FilePath -> IO [FilePath]
sourceFiles root = do
  haskell <- walk (root </> "src") (".hs" `isSuffixOf`)
  native <- walk (root </> "cbits") (\name -> any (`isSuffixOf` name) [".c", ".h", ".m"])
  pure (sort (haskell <> native) <> [root </> "pudu.cabal"])
 where
  walk directory keep = do
    present <- doesDirectoryExist directory
    if not present
      then pure []
      else do
        names <- sort <$> listDirectory directory
        let paths = map (directory </>) names
        directories <- filterM doesDirectoryExist paths
        nested <- concat <$> mapM (`walk` keep) directories
        let files = [path | path <- paths, path `notElem` directories, keep path]
        pure (files <> nested)
