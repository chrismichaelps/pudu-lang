{-| @Pudu.Compiler.Lower — the checked root module to [[Core IR]], or a typed
    refusal.

    This is the one gate between the full language and the native subset, and
    the driver that decides which functions the subset carries: the entry must
    exist and keep milestone 1's shape (no parameters, a block body, a result
    that is the body's own `Int` or `()`), and every other function is
    validated and lowered only if a call chain from the entry reaches it. An
    uncalled declaration is never visited, never refuses, and never reaches the
    core module, because the interpreter never runs it either. The lowering
    itself — state, scopes, blocks, statements, expressions, calls — lives in
    [[Pudu.Compiler.Lower.Body]].
-}
module Pudu.Compiler.Lower
  ( LowerResult (..)
  , lowerProgram
  ) where

import Data.List (sortOn)
import qualified Data.Set as Set
import Data.Text (Text)

import Pudu.Compiler.Lower.Body (lowerEntryBody, lowerFunctionBody)
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), LowerContext (..), LowerState (..), emptyContext, startFunction )
import Pudu.Compiler.Lower.Signature (ensureSignature)
import Pudu.Core
import Pudu.Diagnostic (Diagnostic, sortDiagnostics)
import Pudu.Diagnostic.Native (nativeRefusal)
import Pudu.Frontend.Syntax
  ( Declaration (..)
  , Function (..)
  , Located (..)
  , Module (..)
  , moduleNameText
  )

{-| @Compiler.Lower.Result — the lowered module, or every refusal. A refusal
    never coexists with a module: a program lowers or it does not. -}
data LowerResult
  = Lowered !CoreModule
  | LowerRefused ![Diagnostic]
  deriving stock (Eq, Show)

{-| Lower the root module's entry function and every function reachable from
    it. -}
lowerProgram :: Text -> Module -> LowerResult
lowerProgram entryName parsed
  | not (null (moduleImports parsed)) =
      LowerRefused [nativeRefusal (moduleSpan parsed) "imports"]
  | otherwise = case findEntry of
      Left refusal -> LowerRefused [refusal]
      Right entry -> settle (runWorklist entry)
  where
    findEntry = case entryFunctions of
      function : _ -> Right function
      [] -> Left firstDeclarationRefusal
      where
        entryFunctions =
          [ Located (locatedSpan declaration) function
          | declaration@(Located _ (FunctionDeclaration function)) <- moduleDeclarations parsed
          , locatedValue (functionName function) == entryName
          ]

    firstDeclarationRefusal = case moduleDeclarations parsed of
      Located _ (FunctionDeclaration other) : _ ->
        nativeRefusal
          (locatedSpan (functionName other))
          ("the function '" <> locatedValue (functionName other) <> "'")
      Located declarationSpan _ : _ -> nativeRefusal declarationSpan "this declaration"
      [] -> nativeRefusal (locatedSpan (moduleName parsed)) "programs without a main function"

    table =
      [ (locatedValue (functionName function), Located (locatedSpan declaration) function)
      | declaration@(Located _ (FunctionDeclaration function)) <- moduleDeclarations parsed
      ]

    runWorklist entry =
      let initial =
            LowerState
              { lowerContext = emptyContext entryName table
              , lowerNextLoop = 0
              , lowerLoops = []
              , lowerNextLocal = 0
              , lowerScopes = []
              , lowerFunctionResult = Nothing
              }
          (afterEntry, entryFunction) = lowerEntryBody entry (startFunction initial [] Nothing)
          marked = markVisited afterEntry entryName
       in (drain marked, entryFunction)

    drain state = case contextQueue (lowerContext state) of
      [] -> state
      name : rest ->
        drain (visit state{lowerContext = (lowerContext state){contextQueue = rest}} name)

    visit state name
      | Set.member name (contextVisited (lowerContext state)) = state
      | otherwise = case lookup name table of
          Nothing -> state
          Just function ->
            case ensureSignature function (startFunction state [] Nothing) of
              (afterSignature, Nothing) -> markVisited afterSignature name
              (afterSignature, Just signature) ->
                case lowerFunctionBody
                  function
                  signature
                  (startFunction afterSignature (signatureParameters signature) (Just (signatureResult signature))) of
                  (final, Nothing) -> markVisited final name
                  (final, Just coreFunction) ->
                    markVisited
                      final
                        { lowerContext =
                            (lowerContext final)
                              { contextFunctions = coreFunction : contextFunctions (lowerContext final)
                              }
                        }
                      name

    markVisited state name =
      state
        { lowerContext =
            (lowerContext state)
              { contextVisited = Set.insert name (contextVisited (lowerContext state))
              }
        }

    settle (state, entryFunction) = case sortDiagnostics (contextRefusals (lowerContext state)) of
      [] -> case entryFunction of
        Just function ->
          Lowered
            CoreModule
              { coreModuleName = moduleNameText (locatedValue (moduleName parsed))
              , coreModuleEntry = entryName
              , coreModuleFunctions = sortOn tableIndex (function : contextFunctions (lowerContext state))
              }
        Nothing -> LowerRefused [nativeRefusal (moduleSpan parsed) "this program"]
      refusals -> LowerRefused refusals

    tableIndex :: CoreFunction -> Int
    tableIndex function = case [index | (index, (name, _)) <- zip [0 ..] table, name == coreFunctionName function] of
      index : _ -> index
      [] -> 0
