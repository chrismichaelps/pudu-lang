{-| @Pudu.Backend.Runtime.Dependencies — prerequisites shared by runtime selectors. -}
module Pudu.Backend.Runtime.Dependencies (runtimeDependencies) where

import Data.Text (Text)
import Pudu.Backend.Runtime.Aggregate (aggregateRuntimeDependencies)
import Pudu.Backend.Runtime.Array (arrayRuntimeDependencies)
import Pudu.Backend.Runtime.Char (charRuntimeDependencies)
import Pudu.Backend.Runtime.Float (floatRuntimeDependencies)
import Pudu.Backend.Runtime.Integer (integerRuntimeDependencies)
import Pudu.Backend.Runtime.Output (outputRuntimeDependencies)
import Pudu.Backend.Runtime.Text (textRuntimeDependencies)
import Pudu.Backend.Runtime.Text.Case (textCaseRuntimeDependencies)
import Pudu.Backend.Runtime.Text.Methods (textMethodRuntimeDependencies)
import Pudu.Backend.Runtime.Text.Number (textNumberRuntimeDependencies)
import Pudu.Backend.Runtime.Text.Pieces (textPieceRuntimeDependencies)
import Pudu.Backend.Runtime.Tree (treeRuntimeDependencies)
import Pudu.Backend.Runtime.Range (rangeRuntimeDependencies)
import Pudu.Backend.Runtime.Bytes (bytesRuntimeDependencies)

runtimeDependencies :: Text -> [Text]
runtimeDependencies name = integerRuntimeDependencies name <> floatRuntimeDependencies name
  <> textRuntimeDependencies name <> textMethodRuntimeDependencies name
  <> textCaseRuntimeDependencies name <> charRuntimeDependencies name
  <> aggregateRuntimeDependencies name <> arrayRuntimeDependencies name
  <> textNumberRuntimeDependencies name <> textPieceRuntimeDependencies name
  <> treeRuntimeDependencies name <> rangeRuntimeDependencies name <> bytesRuntimeDependencies name <> outputRuntimeDependencies name
  <> concat [["process_io", "wait_writable"] | name == "error_io"]
  <> ["process_io" | name == "wait_writable"]
  <> ["site" | name == "cleanup"]
