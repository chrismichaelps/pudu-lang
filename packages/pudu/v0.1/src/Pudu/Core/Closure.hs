{-| @Core.Closure — closure identities that lowering and emission share. -}
module Pudu.Core.Closure (textMethodPrefix, isTextMethod, constructorSite, constructorIdentity) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Core (CoreClosureInfo (..))

{-| The site prefix of `toText` taken as a value from a receiver whose type
    declares no `toText`: calling it renders the receiver. -}
textMethodPrefix :: Text
textMethodPrefix = "$text:"

{-| Whether a closure is such a text method, which renders as `<method toText>`. -}
isTextMethod :: CoreClosureInfo -> Bool
isTextMethod info = textMethodPrefix `Text.isPrefixOf` closureSite info

constructorSite :: Text -> Text -> Text
constructorSite owner label = "$constructor:" <> owner <> "." <> label

constructorIdentity :: CoreClosureInfo -> Maybe (Text, Text)
constructorIdentity info = do
  qualified <- Text.stripPrefix "$constructor:" (closureSite info)
  let (owner, label) = Text.breakOnEnd "." qualified
  pure (Text.dropEnd 1 owner, label)
