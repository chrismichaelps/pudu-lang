{-| @Test.Repl.Session.Common — shared session helpers, runners, and fixture loaders -}
module Pudu.Repl.Session.Common
  ( codeOf
  , codesOf
  , feed
  , headName
  , loadFixture
  , submit
  , valueOf
  ) where

import Data.Text (Text)
import qualified Data.Text.IO as TextIO

import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText)
import Pudu.Eval.Render (renderValue)
import Pudu.Repl.Session (EntryResult (..), Session, emptySession, loadModule, submitEntry)
import Pudu.Type (Type (..))
import Pudu.Type.Value (nominalName)

feed :: Session -> [Text] -> IO Session
feed session [] = pure session
feed session (entry : rest) = do
  result <- submitEntry session entry
  feed (resultSession result) rest

submit :: Session -> Text -> IO EntryResult
submit = submitEntry

valueOf :: EntryResult -> Text
valueOf result = maybe "none" renderValue (resultValue result)

codesOf :: EntryResult -> [Text]
codesOf = map codeOf . resultDiagnostics

codeOf :: Diagnostic -> Text
codeOf = diagnosticCodeText . diagnosticCode

headName :: Type -> Text
headName typeValue = case typeValue of
  NominalType identity _ -> nominalName identity
  _ -> "?"

loadFixture :: IO Session
loadFixture = do
  let path = "test-fixtures/repl/Tiny.pudu"
  text <- TextIO.readFile path
  (apply, _, _) <- loadModule path text
  pure (apply emptySession)
