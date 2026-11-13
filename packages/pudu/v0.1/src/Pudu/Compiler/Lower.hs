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
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Set as Set
import Data.Text (Text)

import qualified Data.Map.Strict as Map
import Pudu.Eval.Frozen (Frozen)
import Pudu.Compiler.Lower.Layout (moduleLayouts)
import Pudu.Compiler.Lower.Dynamic (dynamicSums)
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Lower.Types (LowerTypes, emptyTypes, formedCoreTypeIn, lookupScheme, nativeTypes, withShapes)
import Pudu.Compiler.Lower.Method (methodTables)
import Pudu.Compiler.Program (ProgramResult (..), rootCompileResult)
import Pudu.Type (DeclaredShapes, declaredRecords, declaredSums)
import Pudu.Type.Value (NominalId (..), Scheme (..), Type (FunctionTypeRequiring))
import Pudu.Source (Span)
import Pudu.Compiler.Lower.Body (lowerEntryBody, lowerExpression, lowerFunctionBody)
import Pudu.Compiler.Lower.Default (hasDefaults, lowerDefaultedBody)
import Pudu.Compiler.Lower.Loan (lowerLoanedBody)
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), ForeignTarget (..), Instance (..), LowerContext (..), LowerState (..), ModuleScope (..)
  , emptyContext, inModule, startFunction, withTypeBindings )
import Pudu.Compiler.Lower.Signature (ensureSignature)
import Pudu.Core
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Diagnostic (Diagnostic, sortDiagnostics)
import Pudu.Diagnostic.Native (nativeRefusal)
import Pudu.Frontend.Syntax
  ( Declaration (..)
  , Foreign (..)
  , ForeignFunction (..)
  , ForeignParameter (..)
  , Function (..)
  , Located (..)
  , Import (..)
  , Module (..)
  , ModuleName (..)
  , TypeSyntax (..)
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
  {-| Its records and sums formed with its imports, when checking gave them. -}
  , nativeModuleShapes :: !(Maybe DeclaredShapes)
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
    (compileShapes result)

{-| Lower a program of one module. -}
lowerModule :: Text -> Maybe LowerTypes -> Module -> LowerResult
lowerModule entryName types = lowerModuleFolded entryName types Map.empty

{-| Supply the immutable products of the same checked compilation; lowering
    never evaluates a constant initializer itself. -}
lowerModuleFolded :: Text -> Maybe LowerTypes -> Map.Map Text Frozen -> Module -> LowerResult
lowerModuleFolded entryName types constants parsed =
  lowerProgram entryName [NativeModule (moduleNameText (locatedValue (moduleName parsed))) parsed types constants [] Nothing]

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
    -- Shapes formed with the module's imports when checking gave them, so a
    -- field naming another module's type or alias is formed; otherwise the
    -- module's own declarations alone.
    shapesOf native = case nativeModuleShapes native of
      Just shapes -> shapes
      Nothing -> (declaredRecords (nativeModuleSyntax native), declaredSums (nativeModuleSyntax native))
    records = Map.unions
      [ Map.filterWithKey (\identity _ -> owns native identity) (fst (shapesOf native))
      | native <- programModules ]
    sums = Map.union (dynamicSums (map nativeModuleSyntax programModules)) $ Map.unions
      [ Map.filterWithKey (\identity _ -> owns native identity || nominalModule identity == Nothing)
          (snd (shapesOf native))
      | native <- programModules ]

    handles = Set.fromList
      [ NominalId (Just (locatedValue (moduleName (nativeModuleSyntax native)))) (locatedValue named)
      | native <- programModules
      , Located _ (ForeignDeclaration declared) <- moduleDeclarations (nativeModuleSyntax native)
      , named <- foreignTypes declared ]
    scopes = Map.fromList
      [ ( nativeModuleName native
        , ModuleScope
            { scopeTypes = maybe emptyTypes (withShapes records sums handles) (nativeModuleTypes native)
            , scopeFunctions = Set.fromList (map fst (functionsOf native))
            , scopeConstants = Map.fromList
                [ (locatedValue name, Map.lookup (locatedValue name) (nativeModuleConstants native))
                | Located _ (BindingDeclaration _ _ name _ _) <- moduleDeclarations (nativeModuleSyntax native) ]
            , scopeInitializers = Map.fromList
                [ (locatedValue name, initial)
                | Located _ (BindingDeclaration _ _ name _ initial) <- moduleDeclarations (nativeModuleSyntax native) ]
            , scopeSelected = Map.fromList
                [ (locatedValue item, moduleNameText (locatedValue (importModule value)))
                | Located _ value <- moduleImports (nativeModuleSyntax native)
                , item <- importItems value ]
            , scopeQualifiers = Map.fromList
                [ ( maybe (moduleQualifier (locatedValue (importModule value))) locatedValue (importAlias value)
                  , moduleNameText (locatedValue (importModule value)) )
                | Located _ value <- moduleImports (nativeModuleSyntax native)
                , null (importItems value) ]
            , scopeForeign = Map.fromList
                [ ( locatedValue (foreignName function)
                  , ForeignTarget (locatedValue (foreignLibrary declared)) (locatedValue <$> foreignVersion declared)
                      (symbolOf function) (claimOf functions function)
                      (locatedValue (foreignName function) `elem` releasers functions)
                      [index | (index, Located _ parameter) <- zip [0 ..] (foreignParameters function)
                             , foreignParameterOut parameter] )
                | Located _ (ForeignDeclaration declared) <- moduleDeclarations (nativeModuleSyntax native)
                , let functions = map locatedValue (foreignFunctions declared)
                , function <- functions ]
            }
        )
      | native <- programModules ]

    symbolOf function = maybe (locatedValue (foreignName function)) locatedValue (foreignSymbol function)
    -- A borrowed result is held without a claim; an owned or counted one is
    -- released by the function it names, called as that function returns.
    claimOf functions function
      | foreignResultBorrowed function = Just CoreBorrowed
      | Just released <- foreignReleasedBy function
      , release : _ <- [candidate | candidate <- functions, locatedValue (foreignName candidate) == locatedValue released] =
          Just (CoreOwned (foreignResultCounted function) (symbolOf release) (releaseResult (locatedValue (foreignResult release))))
      | otherwise = Nothing
    releasers functions = [locatedValue released | function <- functions, Just released <- [foreignReleasedBy function]]
      <> [locatedValue released | function <- functions, Located _ parameter <- foreignParameters function
         , Just released <- [foreignParameterReleasedBy parameter]]
    -- A release answers nothing or a number, which checking already holds it to.
    releaseResult written = case written of
      NamedType (ModuleName (name :| [])) [] -> maybe CoreUnitType id (lookup name releaseResults)
      _ -> CoreUnitType
    releaseResults =
      [ ("Int8", CoreIntegerType (SignedKind 8)), ("Int16", CoreIntegerType (SignedKind 16))
      , ("Int32", CoreIntegerType (SignedKind 32)), ("Int64", CoreIntegerType (SignedKind 64))
      , ("UInt8", CoreIntegerType (UnsignedKind 8)), ("UInt16", CoreIntegerType (UnsignedKind 16))
      , ("UInt32", CoreIntegerType (UnsignedKind 32)), ("UInt64", CoreIntegerType (UnsignedKind 64))
      , ("Float32", CoreFloatType Float32Width), ("Float64", CoreFloatType Float64Width), ("Bool", CoreBoolType) ]

    (instances, methods, traitMethods, heads) = methodTables scopes
      [ (nativeModuleName native, nativeModuleSyntax native, nativeModuleMethods native) | native <- programModules ]

    runWorklist entry =
      let initial =
            LowerState
              { lowerContext = emptyContext rootName entryKey scopes table instances methods traitMethods heads
              , lowerNextLoop = 0
              , lowerLoops = []
              , lowerNextLocal = 0
              , lowerScopes = []
              , lowerFunctionResult = Nothing
              , lowerDeclaredResult = Nothing
              , lowerCurrentKey = entryKey
              , lowerLoaned = []
              , lowerOpenScopes = []
              , lowerTypeArguments = []
              }
          (afterEntry, entryFunction) = lowerEntryBody entry
            ((startFunction initial [] Nothing){lowerDeclaredResult = declaredEntryResult entry})
          marked = markVisited afterEntry entryKey
       in (drain marked, (\function -> function{coreFunctionName = entryKey}) <$> entryFunction)

    drain state = case contextQueue (lowerContext state) of
      [] -> state
      name : rest ->
        drain (visit state{lowerContext = (lowerContext state){contextQueue = rest}} name)

    visit state name
      | Set.member name (contextVisited (lowerContext state)) = state
      | otherwise = case target state name of
          Nothing -> state
          Just (owner, function, bindings) ->
            case ensureSignature name function ((startFunction (withTypeBindings bindings (inModule owner state)) [] Nothing){lowerCurrentKey = name}) of
              (afterSignature, Nothing) -> markVisited afterSignature name
              (afterSignature, Just signature) ->
                case loaned signature (if hasDefaults (locatedValue function) then lowerDefaultedBody lowerExpression lowerFunctionBody else lowerFunctionBody)
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

    loaned signature
      | null (signatureLoaned signature) = id
      | otherwise = lowerLoanedBody

    -- Copies of generic bodies are registered while lowering their callers.
    target state name = case lookup name table of
      Just (owner, function) -> Just (owner, function, Map.empty)
      Nothing -> (\found -> (instanceModule found, instanceFunction found, instanceBindings found))
        <$> Map.lookup name (contextInstances (lowerContext state))

    -- `?` in the entry returns at its declared type, before any `return` says so.
    declaredEntryResult entry = case lookupScheme (maybe emptyTypes scopeTypes (Map.lookup rootName scopes)) (locatedValue (functionName (locatedValue entry))) of
      Just Scheme{schemeParams = [], schemeType = FunctionTypeRequiring _ [] _ result} ->
        formedCoreTypeIn (maybe emptyTypes scopeTypes (Map.lookup rootName scopes)) result
      _ -> Nothing

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
              , coreModuleLayouts = moduleLayouts (maybe emptyTypes scopeTypes (Map.lookup rootName scopes)) (contextClosures (lowerContext state)) functions
              , coreModuleClosures = contextClosures (lowerContext state)
              }
        Nothing -> LowerRefused [nativeRefusal (moduleSpan parsed) "this program"]
      refusals -> LowerRefused refusals

    tableIndex :: CoreFunction -> Int
    tableIndex function = case [index | (index, (name, _)) <- zip [0 ..] table, name == coreFunctionName function] of
      index : _ -> index
      [] -> 0
