module Pudu.Version
  ( versionText
  , languageConstraint
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Data.Version (showVersion, versionBranch)
import qualified Paths_pudu as Package

versionText :: Text
versionText = Text.pack (showVersion Package.version)

languageConstraint :: Text
languageConstraint = ">=" <> versionText <> " <" <> nextMinor
 where
  nextMinor = case versionBranch Package.version of
    major : minor : _ -> Text.pack (show major <> "." <> show (minor + 1) <> ".0")
    major : _ -> Text.pack (show (major + 1) <> ".0.0")
    [] -> versionText
