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
  , NativeModule (..)
  , compiledNativeModule
  , lowerModule
  , lowerModuleFolded
  , lowerProgram
  , programNativeModules
  ) where

import Data.List (find, sortOn)
import qualified Data.Set as Set
import Data.Text (Text)

import qualified Data.Map.Strict as Map
import Pudu.Eval.Frozen (Frozen)
import Pudu.Compiler.Lower.Layout (moduleLayouts)
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Lower.Types (LowerTypes, emptyTypes, nativeTypes, withShapes)
import Pudu.Compiler.Lower.Method (methodTables)
import Pudu.Compiler.Program (ProgramResult (..), rootCompileResult)
import Pudu.Type (declaredRecords, declaredSums)
import Pudu.Type.Value (NominalId (..), Scheme)
import Pudu.Source (Span)
import Pudu.Compiler.Lower.Body (lowerEntryBody, lowerFunctionBody)
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), Instance (..), LowerContext (..), LowerState (..), ModuleScope (..)
  , emptyContext, inModule, startFunction, withTypeBindings )
import Pudu.Compiler.Lower.Signature (ensureSignature)
import Pudu.Core
import Pudu.Diagnostic (Diagnostic, sortDiagnostics)
import Pudu.Diagnostic.Native (nativeRefusal)
import Pudu.Frontend.Syntax
  ( Declaration (..)
  , Function (..)
  , Located (..)
  , Import (..)
  , Module (..)
  , moduleNameText
  )
import Pudu.Frontend.Syntax.Name (moduleQualifier)

{-| @Compiler.Lower.Result — the lowered module, or every refusal. A refusal
    never coexists with a module: a program lowers or it does not. -}
data LowerResult
  = Lowered !CoreModule
  | LowerRefused ![Diagnostic]
  deriving stock (Eq, Show)

{-| A module of the program as native lowering reads it: its name, its
    checked syntax and its checked facts. -}
data NativeModule = NativeModule
  { nativeModuleName :: !Text
  , nativeModuleSyntax :: !Module
  , nativeModuleTypes :: !(Maybe LowerTypes)
  , nativeModuleConstants :: !(Map.Map Text Frozen)
  {-| The methods its own declarations provide, as checking declared them. -}
  , nativeModuleMethods :: ![(NominalId, Text, Scheme, Span)]
  }

{-| Every module of a compiled program as native lowering reads it, the root
    first and the rest in the order the program was compiled; nothing when the
    root produced no module. -}
programNativeModules :: ProgramResult -> Maybe [NativeModule]
programNativeModules program = do
  rootResult <- rootCompileResult program
  parsed <- compileModule rootResult
  pure $
    compiledNativeModule parsed rootResult
      : [ compiledNativeModule syntax result
        | name <- programOrder program
        , Just name /= programRoot program
        , Just result <- [Map.lookup name (programModules program)]
        , Just syntax <- [compileModule result]
        ]

{-| One checked module as native lowering reads it. -}
compiledNativeModule :: Module -> CompileResult -> NativeModule
compiledNativeModule syntax result =
  NativeModule (moduleNameText (locatedValue (moduleName syntax))) syntax
    (nativeTypes (compileTypes result) (compileSchemes result)) (compileFolded result) (compileMethods result)

{-| Lower a program of one module. -}
lowerModule :: Text -> Maybe LowerTypes -> Module -> LowerResult
lowerModule entryName types = lowerModuleFolded entryName types Map.empty

{-| Supply the immutable products of the same checked compilation; lowering
    never evaluates a constant initializer itself. -}
lowerModuleFolded :: Text -> Maybe LowerTypes -> Map.Map Text Frozen -> Module -> LowerResult
lowerModuleFolded entryName types constants parsed =
  lowerProgram entryName [NativeModule (moduleNameText (locatedValue (moduleName parsed))) parsed types constants []]

{-| Lower the root module's entry function and every function reachable from
    it, in whichever module each is declared. The root comes first. -}
lowerProgram :: Text -> [NativeModule] -> LowerResult
lowerProgram _ [] = LowerRefused []
lowerProgram entryName programModules@(rootModule : _)
  | Just missing <- find (null . nativeModuleTypes) programModules =
      LowerRefused [nativeRefusal (moduleSpan (nativeModuleSyntax missing)) "missing solved native type facts"]
  | otherwise = case findEntry of
      Left refusal -> LowerRefused [refusal]
      Right entry -> settle (runWorklist entry)
  where
    parsed = nativeModuleSyntax rootModule
    rootName = nativeModuleName rootModule
    entryKey = rootName <> "." <> entryName

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

    functionsOf native =
      [ (locatedValue (functionName function), Located (locatedSpan declaration) function)
      | declaration@(Located _ (FunctionDeclaration function)) <- moduleDeclarations (nativeModuleSyntax native)
      ]

    table =
      [ (nativeModuleName native <> "." <> name, (nativeModuleName native, function))
      | native <- programModules
      , (name, function) <- functionsOf native
      ]

    -- Each module's own records and sums, and the built-in sums once; a type
    -- is named by its canonical identity, so modules' types never meet.
    owns native identity = nominalModule identity == Just (locatedValue (moduleName (nativeModuleSyntax native)))
    records = Map.unions
      [ Map.filterWithKey (\identity _ -> owns native identity) (declaredRecords (nativeModuleSyntax native))
      | native <- programModules ]
    sums = Map.unions
      [ Map.filterWithKey (\identity _ -> owns native identity || nominalModule identity == Nothing)
          (declaredSums (nativeModuleSyntax native))
      | native <- programModules ]

    scopes = Map.fromList
      [ ( nativeModuleName native
        , ModuleScope
            { scopeTypes = maybe emptyTypes (withShapes records sums) (nativeModuleTypes native)
            , scopeFunctions = Set.fromList (map fst (functionsOf native))
            , scopeConstants = Map.fromList
                [ (locatedValue name, Map.lookup (locatedValue name) (nativeModuleConstants native))
                | Located _ (BindingDeclaration _ _ name _ _) <- moduleDeclarations (nativeModuleSyntax native) ]
            , scopeSelected = Map.fromList
                [ (locatedValue item, moduleNameText (locatedValue (importModule value)))
                | Located _ value <- moduleImports (nativeModuleSyntax native)
                , item <- importItems value ]
            , scopeQualifiers = Map.fromList
                [ ( maybe (moduleQualifier (locatedValue (importModule value))) locatedValue (importAlias value)
                  , moduleNameText (locatedValue (importModule value)) )
                | Located _ value <- moduleImports (nativeModuleSyntax native)
                , null (importItems value) ]
            }
        )
      | native <- programModules ]

    (instances, methods, traitMethods) = methodTables scopes
      [ (nativeModuleName native, nativeModuleSyntax native, nativeModuleMethods native) | native <- programModules ]

    runWorklist entry =
      let initial =
            LowerState
              { lowerContext = emptyContext rootName entryKey scopes table instances methods traitMethods
              , lowerNextLoop = 0
              , lowerLoops = []
              , lowerNextLocal = 0
              , lowerScopes = []
              , lowerFunctionResult = Nothing
              }
          (afterEntry, entryFunction) = lowerEntryBody entry (startFunction initial [] Nothing)
          marked = markVisited afterEntry entryKey
       in (drain marked, (\function -> function{coreFunctionName = entryKey}) <$> entryFunction)

    drain state = case contextQueue (lowerContext state) of
      [] -> state
      name : rest ->
        drain (visit state{lowerContext = (lowerContext state){contextQueue = rest}} name)

    visit state name
      | Set.member name (contextVisited (lowerContext state)) = state
      | otherwise = case target name of
          Nothing -> state
          Just (owner, function, bindings) ->
            case ensureSignature name function (startFunction (withTypeBindings bindings (inModule owner state)) [] Nothing) of
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
                              { contextFunctions = coreFunction{coreFunctionName = name} : contextFunctions (lowerContext final)
                              }
                        }
                      name

    target name = case lookup name table of
      Just (owner, function) -> Just (owner, function, Map.empty)
      Nothing -> (\found -> (instanceModule found, instanceFunction found, instanceBindings found))
        <$> Map.lookup name instances

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
          let functions = sortOn tableIndex (function : contextFunctions (lowerContext state))
           in Lowered
            CoreModule
              { coreModuleName = moduleNameText (locatedValue (moduleName parsed))
              , coreModuleEntry = entryKey
              , coreModuleFunctions = functions
              , coreModuleLayouts = moduleLayouts (maybe emptyTypes scopeTypes (Map.lookup rootName scopes)) functions
              }
        Nothing -> LowerRefused [nativeRefusal (moduleSpan parsed) "this program"]
      refusals -> LowerRefused refusals

    tableIndex :: CoreFunction -> Int
    tableIndex function = case [index | (index, (name, _)) <- zip [0 ..] table, name == coreFunctionName function] of
      index : _ -> index
      [] -> 0
