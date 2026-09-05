{-| @Module.Syntax.Name — preserves segmented module paths -}
module Pudu.Frontend.Syntax.Name
  ( ModuleName (..)
  , moduleNameText
  , moduleQualifier
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

{-| The name an unaliased import is reached through.

    `import Std.Map` binds that module's names under `Map`, and `import Std.Map
    as M` under `M` instead. Every side that resolves a qualifier asks here, so
    a name the checker admits is one the evaluator can find: the rule lived in
    two copies in the checker and in neither the evaluator, which is a shape
    where the two can agree on a program that does not run. -}
moduleQualifier :: ModuleName -> Text
moduleQualifier = NonEmpty.last . moduleNameSegments
