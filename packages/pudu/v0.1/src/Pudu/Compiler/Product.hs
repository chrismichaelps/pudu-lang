{-| @Program.Compiler.Product — admits caches and bounds published product lifetime. -}
module Pudu.Compiler.Product
  ( ProductUse (..)
  , checkedFor
  , frontendFor
  , publishProduct
  ) where

import Data.ByteString (ByteString)
import Pudu.Compiler (CompileResult (..), FrontendResult (..), runFrontend)
import Pudu.Compiler.Cache
  ( CheckedProduct (..), ProductCache, lookupChecked, lookupFrontend
  , storeChecked, storeFrontend )
import Pudu.Source (Source)

{-| Analysis keeps editor facts; execution publishes the same products whether
    they were checked now or restored from a cache. -}
data ProductUse = AnalysisProducts | ExecutionProducts

publishProduct :: ProductUse -> CompileResult -> CompileResult
publishProduct AnalysisProducts compiled = compiled
publishProduct ExecutionProducts compiled = compiled
  { compileTokens = []
  , compileSyntax = compileModule compiled
  , compileResolution = Nothing
  , compileTypes = Nothing
  , compileDocs = Nothing
  , compileMethods = []
  }

frontendFor :: ProductUse -> ProductCache -> Source -> IO FrontendResult
frontendFor AnalysisProducts _ source = pure (runFrontend source)
frontendFor ExecutionProducts cache source = do
  stored <- lookupFrontend cache source
  case stored of
    Just parsed -> pure (FrontendResult [] (Just parsed) [])
    Nothing -> do
      let frontend = runFrontend source
      case frontendModule frontend of
        Just parsed | null (frontendDiagnostics frontend) -> storeFrontend cache source parsed
        _ -> pure ()
      pure frontend{frontendTokens = []}

checkedFor :: ProductUse -> ProductCache -> ByteString -> Source -> FrontendResult -> IO CompileResult -> IO CompileResult
checkedFor AnalysisProducts _ _ _ _ compile = compile
checkedFor ExecutionProducts cache graph source frontend compile = do
  stored <- lookupChecked cache graph source
  compiled <- case stored of
    Just reused ->
      pure CompileResult
        { compileTokens = frontendTokens frontend
        , compileModule = Just (checkedModule reused)
        , compileSyntax = Just (checkedModule reused)
        , compileResolution = Nothing
        , compileTypes = Nothing
        , compileIntegerKinds = checkedIntegerKinds reused
        , compileDocs = Nothing
        , compileDiagnostics = []
        , compileMethods = []
        , compileFolded = checkedFolded reused
        }
    Nothing -> do
      fresh <- compile
      case compileModule fresh of
        Just checked | null (compileDiagnostics fresh) ->
          storeChecked cache graph source
            (CheckedProduct checked (compileIntegerKinds fresh) (compileFolded fresh))
        _ -> pure ()
      pure fresh
  pure (publishProduct ExecutionProducts compiled)
