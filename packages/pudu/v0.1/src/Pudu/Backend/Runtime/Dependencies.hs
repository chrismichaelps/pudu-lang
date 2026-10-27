{-| @Pudu.Backend.Runtime.Dependencies — prerequisites shared by runtime selectors. -}
module Pudu.Backend.Runtime.Dependencies (runtimeDependencies) where

import Data.Text (Text)
import Pudu.Backend.Runtime.Float (floatRuntimeDependencies)
import Pudu.Backend.Runtime.Integer (integerRuntimeDependencies)
import Pudu.Backend.Runtime.Text (textRuntimeDependencies)

runtimeDependencies :: Text -> [Text]
runtimeDependencies name = integerRuntimeDependencies name <> floatRuntimeDependencies name
  <> textRuntimeDependencies name
