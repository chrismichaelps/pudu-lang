{-| Complete-program evidence for the shipped view modules. -}
module Pudu.Compiler.Program.ViewSpec (viewProperties) where

import Data.Text (Text)
import Pudu.Compiler.Program.Common (runEntry, runtimeCodes)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

viewProperties :: [(String, IO Property)]
viewProperties =
  [ ("view APIs preserve their original contracts", fixtures
      [("UsesIterChain", "14"), ("UsesSpan", "6"), ("UsesMdSpan", "8"), ("UsesStringView", "8"), ("UsesMemory", "7")])
  , ("view boundaries refuse overflow and certify layouts", fixtures [("UsesViewBoundaries", "4")])
  , ("optional iterator views stay lazy and restartable", fixtures [("UsesIterViews", "6")])
  , ("string views search and copy UTF-8 code units", fixtures [("UsesStringViewSearch", "4")])
  ]

fixtures :: [(String, Text)] -> IO Property
fixtures cases = conjoin <$> traverse check cases
 where
  check (name, expected) = do
    let path = "test-fixtures/stdlib/" <> name <> ".pudu"
    actual <- runEntry path
    diagnostics <- runtimeCodes path
    pure (counterexample name (conjoin [actual === Just expected, diagnostics === []]))
