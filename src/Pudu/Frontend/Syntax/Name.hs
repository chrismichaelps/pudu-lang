{-| @Module.Syntax.Name — preserves segmented module paths -}
module Pudu.Frontend.Syntax.Name
  ( ModuleName (..)
  , moduleNameText
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text

{-| @Module.Syntax.Identity — stores non-empty path segments -}
newtype ModuleName = ModuleName {moduleNameSegments :: NonEmpty Text}
  deriving stock (Eq, Ord, Show)

moduleNameText :: ModuleName -> Text
moduleNameText = Text.intercalate "." . NonEmpty.toList . moduleNameSegments
