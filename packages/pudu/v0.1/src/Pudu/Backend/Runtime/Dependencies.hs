{-| @Pudu.Backend.Runtime.Dependencies — prerequisites shared by runtime selectors. -}
module Pudu.Backend.Runtime.Dependencies (runtimeDependencies) where

import Data.Text (Text)
import Pudu.Backend.Runtime.Aggregate (aggregateRuntimeDependencies)
import Pudu.Backend.Runtime.Array (arrayRuntimeDependencies)
import Pudu.Backend.Runtime.Char (charRuntimeDependencies)
import Pudu.Backend.Runtime.Float (floatRuntimeDependencies)
import Pudu.Backend.Runtime.Integer (integerRuntimeDependencies)
import Pudu.Backend.Runtime.Text (textRuntimeDependencies)
import Pudu.Backend.Runtime.Text.Case (textCaseRuntimeDependencies)
import Pudu.Backend.Runtime.Text.Methods (textMethodRuntimeDependencies)
import Pudu.Backend.Runtime.Text.Number (textNumberRuntimeDependencies)
import Pudu.Backend.Runtime.Text.Pieces (textPieceRuntimeDependencies)

runtimeDependencies :: Text -> [Text]
runtimeDependencies name = integerRuntimeDependencies name <> floatRuntimeDependencies name
  <> textRuntimeDependencies name <> textMethodRuntimeDependencies name
  <> textCaseRuntimeDependencies name <> charRuntimeDependencies name
  <> aggregateRuntimeDependencies name <> arrayRuntimeDependencies name
  <> textNumberRuntimeDependencies name <> textPieceRuntimeDependencies name
