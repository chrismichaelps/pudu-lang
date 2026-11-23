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
  , lowerLibrary
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
import Pudu.Compiler.Lower.Dynamic (dynamicSums, runtimeCarriers)
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Lower.Foreign (callbackSignatureOf)
import Pudu.Compiler.Lower.Generic (substitute)
import qualified Pudu.Foreign.Callback as Callback
import qualified Data.List.NonEmpty as NonEmpty
import Pudu.Foreign.Crossing (ObjectiveCMethod (..), ReturnedRun (..), foreignBounds, objectiveCMethod, recordLayouts, resolveReturnedRun)
import Pudu.Compiler.Lower.Types (LowerTypes, emptyTypes, formedCoreTypeIn, lookupScheme, nativeTypes, withShapes)
import Pudu.Compiler.Lower.Method (methodTables)
import Pudu.Compiler.Program (ProgramResult (..), rootCompileResult)
import Pudu.Type (DeclaredShapes, declaredRecords, declaredSums)
import Pudu.Type.Value (NominalId (..), Scheme (..), Type (FunctionTypeRequiring), nominalKey)
import Pudu.Source (Span, sameSpanSource, spanStart, spanEnd)
import Pudu.Compiler.Lower.Body (lowerEntryBody, lowerExpression, lowerFunctionBody)
import Pudu.Compiler.Lower.Default (takesSuppliedCount, lowerDefaultedBody)
import Pudu.Compiler.Lower.Loan (lowerLoanedBody)
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), ForeignTarget (..), Instance (..), LowerContext (..), LowerState (..), ModuleScope (..)
  , callableTemplateLayout, emptyContext, inModule, startFunction, withTypeBindings )
import Pudu.Compiler.Lower.Signature (ensureSignature)
import Pudu.Core
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Diagnostic (Diagnostic, sortDiagnostics)
import Pudu.Diagnostic.Native (nativeRefusal)
import Pudu.Frontend.Syntax
  ( Declaration (..)
  , Foreign (..)
  , foreignCallbackNames
  , ForeignDelegate (..)
  , ForeignDelegateMethod (..)
  , ForeignFunction (..)
  , ForeignParameter (..)
  , Function (..)
  , Located (..)
  , Import (..)
  , Module (..)
  , ModuleName (..)
  , TypeSyntax (..)
  , Visibility (..)
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
  , nativeModuleDynamicWidenings :: ![(Span, NominalId, Type)]
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
    (compileShapes result) (compileDynamicWidenings result)

{-| Lower a program of one module. -}
lowerModule :: Text -> Maybe LowerTypes -> Module -> LowerResult
lowerModule entryName types = lowerModuleFolded entryName types Map.empty

{-| Supply the immutable products of the same checked compilation; lowering
    never evaluates a constant initializer itself. -}
lowerModuleFolded :: Text -> Maybe LowerTypes -> Map.Map Text Frozen -> Module -> LowerResult
lowerModuleFolded entryName types constants parsed =
  lowerProgram entryName [NativeModule (moduleNameText (locatedValue (moduleName parsed))) parsed types constants [] Nothing []]

{-| Lower the root module's entry function and every function reachable from
    it, in whichever module each is declared. The root comes first. -}
lowerProgram :: Text -> [NativeModule] -> LowerResult
lowerProgram = lowerRooted False

{-| Lower for a library a host application links: the root module's exported
    functions are roots beside the entry, so each is lowered even when the
    entry never calls it. -}
lowerLibrary :: Text -> [NativeModule] -> LowerResult
lowerLibrary = lowerRooted True

lowerRooted :: Bool -> Text -> [NativeModule] -> LowerResult
lowerRooted _ _ [] = LowerRefused []
lowerRooted library entryName programModules@(rootModule : _)
  | Just missing <- find (null . nativeModuleTypes) programModules =
      LowerRefused [nativeRefusal (moduleSpan (nativeModuleSyntax missing)) "missing solved native type facts"]
  | not (null exportRefusals) = LowerRefused exportRefusals
  | otherwise = case findEntry of
      Left refusal -> LowerRefused [refusal]
      Right entry -> discover entry provenWidenings (dynamicSums syntaxes provenWidenings) Map.empty Map.empty Map.empty Map.empty
  where
    parsed = nativeModuleSyntax rootModule
    rootName = nativeModuleName rootModule
    entryKey = rootName <> "." <> entryName

    exported =
      [ function
      | library
      , Located _ (FunctionDeclaration function) <- moduleDeclarations parsed
      , functionVisibility function == Exported
      , locatedValue (functionName function) /= entryName
      ]
    exportKeys = [rootName <> "." <> locatedValue (functionName function) | function <- exported]
    -- A C caller passes every argument at a fixed type.
    exportRefusals =
      [ nativeRefusal (locatedSpan (functionName function)) ("an exported function " <> reason)
      | function <- exported
      , reason <-
          [ "with type parameters" | not (null (functionTypeParams function)) ]
      ]

    findEntry = case entryFunctions of
      [function] -> Right function
      [] -> Left firstDeclarationRefusal
      _ : duplicate : _ ->
        Left (nativeRefusal (locatedSpan (functionName (locatedValue duplicate))) "an ambiguous entry function")
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
    sums = Map.unions
      [ Map.filterWithKey (\identity _ -> owns native identity || nominalModule identity == Nothing)
          (snd (shapesOf native))
      | native <- programModules ]
    syntaxes = map nativeModuleSyntax programModules
    moduleWidenings = Map.fromList [(nativeModuleName native, nativeModuleDynamicWidenings native) | native <- programModules]
    provenWidenings = concat (Map.elems moduleWidenings)

    discover entry known dynamicShapes results callables failures mutable =
      let pass@(state, _) = runWorklist entry (Map.union dynamicShapes sums) results callables failures mutable
          context = lowerContext state
          extended = known <> specializedWidenings context
          resolved = dynamicSums syntaxes extended
          discoveredResults = Map.unionWith Set.union results (contextObservedResults context)
          discoveredCallables = Map.union (contextObservedCallables context) callables
          discoveredFailures = Map.unionWith Set.union failures (contextObservedTaskFailures context)
          discoveredMutable = Map.unionWith Set.union mutable (contextObservedMutableLayouts context)
       in if resolved == dynamicShapes && discoveredResults == results
            && discoveredFailures == failures && discoveredMutable == mutable
            && (not (contextNeedsCallableReplay context)
              || Map.map callableTemplateLayout discoveredCallables == Map.map callableTemplateLayout callables)
            then settle pass
            else discover entry extended resolved discoveredResults discoveredCallables discoveredFailures discoveredMutable

    specializedWidenings context =
      [ (at, trait, substitute bindings payload)
      | key <- Set.toList (contextVisited context)
      , Just found <- [Map.lookup key (contextInstances context)]
      , let bindings = instanceBindings found
            bodySpan = locatedSpan (instanceFunction found)
      , not (Map.null bindings)
      , (at, trait, payload) <- Map.findWithDefault [] (instanceModule found) moduleWidenings
      , sameSpanSource bodySpan at
      , spanStart bodySpan <= spanStart at, spanEnd at <= spanEnd bodySpan ]

    handles = Set.fromList
      [ NominalId (Just (locatedValue (moduleName (nativeModuleSyntax native)))) (locatedValue named)
      | native <- programModules
      , Located _ (ForeignDeclaration declared) <- moduleDeclarations (nativeModuleSyntax native)
      , named <- foreignTypes declared ]
    callbackTypes = Set.fromList
      [ NominalId (Just (locatedValue (moduleName (nativeModuleSyntax native)))) (locatedValue named)
      | native <- programModules
      , Located _ (ForeignDeclaration declared) <- moduleDeclarations (nativeModuleSyntax native)
      , named <- foreignCallbackNames declared ]
    callbackDeclarations native =
      [ (declared, either (const Map.empty) id
          (Callback.checkCallbackDeclarations (Set.fromList (map locatedValue (foreignTypes declared)))
            (recordLayouts declarations) (foreignCallbacks declared)))
      | Located _ (ForeignDeclaration declared) <- declarations ]
      where declarations = moduleDeclarations (nativeModuleSyntax native)

    coreSignature native name = callbackSignatureOf (nativeModuleName native) name . locatedValue
    groupsOf declared callbacks = either (const Map.empty) id $
      Callback.checkCallbackGroups (Set.fromList (map locatedValue (foreignTypes declared)))
        callbacks (foreignCallbackGroups declared)
    coreGroup native owner (Located _ members) =
      ( coreSignature native owner (Callback.callbackMemberSignature (NonEmpty.head members))
      , map Callback.callbackMemberField (NonEmpty.toList members) )
    coreDelegate native groups delegate = do
      let group = locatedValue (foreignDelegateGroup delegate)
      located@(Located _ members) <- Map.lookup group groups
      let entries = zip [0 ..] (NonEmpty.toList members)
          method written = do
            let member = locatedValue (foreignDelegateMember written)
            (ordinal, entry) <- lookup member [(Callback.callbackMemberField entry, (ordinal, entry)) | (ordinal, entry) <- entries]
            pure ( locatedValue (foreignDelegateSelector written)
                 , (coreSignature native group (Callback.callbackMemberSignature entry))
                     {coreCallbackProjection = Just (ordinal, member)} )
      resolved <- traverse method (foreignDelegateMethods delegate)
      pure (CoreDelegate (locatedValue (foreignDelegateSymbol delegate)) (fst (coreGroup native group located)) resolved)
    callbackSlots native signatures groups function =
      [ CoreCallbackSlot (Callback.callbackPlacement pair)
          ((callbackSignatureOf (nativeModuleName native) (Callback.callbackTypeName pair) (Callback.callbackSlotSignature pair))
            {coreCallbackProjection = Callback.callbackProjection pair})
      | pair <- either (const []) id (Callback.callbackPairs signatures groups function) ]

    scopes activeSums = Map.fromList
      [ ( nativeModuleName native
        , ModuleScope
            { scopeTypes = maybe emptyTypes (withShapes records activeSums handles callbackTypes) (nativeModuleTypes native)
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
                      (maybe (symbolOf function) objectiveCSelector method) method (claimOf functions function)
                      (locatedValue (foreignName function) `elem` releasers functions)
                      [index | (index, Located _ parameter) <- zip [0 ..] (foreignParameters function)
                             , foreignParameterOut parameter]
                      [claimFor functions False (foreignParameterReleasedBy parameter)
                      | Located _ parameter <- foreignParameters function, foreignParameterOut parameter]
                      (callbackSlots native callbacks groups written)
                      splitCallbacks
                      [ (index, exclusive)
                      | (index, Located _ parameter) <- zip [0 ..] (foreignParameters function)
                      , not (foreignParameterOut parameter)
                      , Just (Located _ (ReferenceType exclusive _)) <- [foreignParameterType parameter]
                      ]
                      [ index
                      | (index, Located _ parameter) <- zip [0 ..] (foreignParameters function)
                      , foreignParameterNullable parameter /= Nothing
                      ]
                      (either (const []) id
                        (foreignBounds foreignHandles layouts (foreignParameters function)))
                      (returnedTarget native foreignHandles layouts functions function) )
                | (declared, callbacks) <- callbackDeclarations native
                , let functions = map locatedValue (foreignFunctions declared)
                      foreignHandles = Set.fromList (map locatedValue (foreignTypes declared))
                      groups = groupsOf declared callbacks
                      splitCallbacks = or
                        [ foreignParameterCallbackPassing parameter /= Nothing
                        | function <- functions, Located _ parameter <- foreignParameters function ]
                , written@(Located _ function) <- foreignFunctions declared
                , let method = objectiveCMethod (foreignClasses declared) function ]
            , scopeCallbacks = Map.unions
                [ Map.mapWithKey (coreSignature native) callbacks
                | (_, callbacks) <- callbackDeclarations native ]
            , scopeCallbackGroups = Map.unions
                [ Map.mapWithKey (coreGroup native) (groupsOf declared callbacks)
                | (declared, callbacks) <- callbackDeclarations native ]
            , scopeDelegates = Map.fromList
                [ (locatedValue (foreignDelegateName delegate), core)
                | (declared, callbacks) <- callbackDeclarations native
                , Located _ delegate <- foreignDelegates declared
                , Just core <- [coreDelegate native (groupsOf declared callbacks) delegate] ]
            }
        )
      | native <- programModules
      , let layouts = recordLayouts (moduleDeclarations (nativeModuleSyntax native)) ]

    symbolOf function = maybe (locatedValue (foreignName function)) locatedValue (foreignSymbol function)
    returnedTarget native handlesOfBlock layouts functions function = do
      run <- either (const Nothing) id
        (resolveReturnedRun handlesOfBlock layouts
          (Map.fromList [(locatedValue (foreignName candidate), candidate) | candidate <- functions]) function)
      let handle = returnedRunHandle run
          owner = NominalId (Just (locatedValue (moduleName (nativeModuleSyntax native)))) handle
      pure (returnedRunLengthSlot run, CoreHandleType (nominalKey owner) handle)
    -- A borrowed result is held without a claim; an owned or counted one is
    -- released by the function it names, called as that function returns.
    claimOf functions function
      | foreignResultBorrowed function = Just CoreBorrowed
      | otherwise = claimFor functions (foreignResultCounted function) (foreignReleasedBy function)
    claimFor functions counted written
      | Just released <- written
      , Just release <- find ((== locatedValue released) . locatedValue . foreignName) functions =
          Just (CoreOwned counted (symbolOf release) (releaseResult (locatedValue (foreignResult release))))
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

    runWorklist entry activeSums results callables failures mutable =
      let activeScopes = scopes activeSums
          (instances, methods, traitMethods, heads) = methodTables activeScopes
            [ (nativeModuleName native, nativeModuleSyntax native, nativeModuleMethods native) | native <- programModules ]
          initial =
            LowerState
              { lowerContext = (emptyContext rootName entryKey activeScopes table instances methods traitMethods heads)
                  { contextRuntimeResults = results, contextKnownCallables = callables
                  , contextTaskFailures = failures, contextMutableLayouts = mutable }
              , lowerNextLoop = 0
              , lowerLoops = []
              , lowerNextLocal = 0
              , lowerScopes = []
              , lowerMutableSites = Map.empty
              , lowerFunctionResult = Nothing
              , lowerFlexibleResult = False
              , lowerObservedReturns = Set.empty
              , lowerDeclaredResult = Nothing
              , lowerCurrentKey = entryKey
              , lowerLoaned = []
              , lowerOpenScopes = []
              , lowerTypeArguments = []
              }
          (afterEntry, entryFunction) = lowerEntryBody entry
            ((startFunction initial [] Nothing){lowerDeclaredResult = declaredEntryResult (contextTypes (lowerContext initial)) entry})
          marked = queueExports (markVisited afterEntry entryKey)
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
                case loaned signature (if takesSuppliedCount signature then lowerDefaultedBody lowerExpression lowerFunctionBody else lowerFunctionBody)
                  function
                  signature
                  ((startFunction afterSignature (signatureParameters signature) (Just (signatureResult signature)))
                    {lowerFlexibleResult = name `notElem` exportKeys}) of
                  (final, Nothing) -> markVisited final name
                  (final, Just coreFunction) ->
                    let recorded = observeResult name signature coreFunction final
                     in markVisited
                      recorded
                        { lowerContext =
                            (lowerContext recorded)
                              { contextFunctions = coreFunction{coreFunctionName = name} : contextFunctions (lowerContext recorded)
                              }
                        }
                      name

    observeResult name signature function state
      | lowerFlexibleResult state
      , let observed = lowerObservedReturns state <>
              foldMap (runtimeCarriers . ownResult . coreExpressionType) (coreBlockResult (coreFunctionBody function))
      , not (observed `Set.isSubsetOf` runtimeCarriers (signatureResult signature)) =
          let context = lowerContext state
           in state{lowerContext = context{contextObservedResults =
                Map.insertWith Set.union name observed (contextObservedResults context)}}
      | otherwise = state
     where
      ownResult (CoreTupleType (result : _)) | not (null (signatureLoaned signature)) = result
      ownResult result = result

    loaned signature
      | null (signatureLoaned signature) = id
      | otherwise = lowerLoanedBody

    -- Copies of generic bodies are registered while lowering their callers.
    target state name = case lookup name table of
      Just (owner, function) -> Just (owner, function, Map.empty)
      Nothing -> (\found -> (instanceModule found, instanceFunction found, instanceBindings found))
        <$> Map.lookup name (contextInstances (lowerContext state))

    -- `?` in the entry returns at its declared type, before any `return` says so.
    declaredEntryResult types entry = case lookupScheme types (locatedValue (functionName (locatedValue entry))) of
      Just Scheme{schemeParams = [], schemeType = FunctionTypeRequiring _ _ _ result} ->
        formedCoreTypeIn types result
      _ -> Nothing

    queueExports state =
      state{lowerContext = (lowerContext state){contextQueue = exportKeys <> contextQueue (lowerContext state)}}

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
          let lowered = contextFunctions (lowerContext state)
              wrappers = Map.fromList
                [ (key, awaitExport declaration functionBody answer)
                | (key, declaration) <- zip exportKeys exported
                , functionAsync declaration
                , functionBody <- lowered
                , coreFunctionName functionBody == key
                , CoreFunctionType [] answer <- [coreFunctionResult functionBody] ]
              functions = sortOn tableIndex (function : lowered <> Map.elems wrappers)
           in Lowered
            CoreModule
              { coreModuleName = moduleNameText (locatedValue (moduleName parsed))
              , coreModuleEntry = entryKey
              , coreModuleFunctions = functions
              , coreModuleLayouts = moduleLayouts (maybe emptyTypes scopeTypes (Map.lookup rootName (contextModules (lowerContext state)))) (contextClosures (lowerContext state)) functions
              , coreModuleClosures = contextClosures (lowerContext state)
              , coreModuleExports =
                  [ maybe key coreFunctionName (Map.lookup key wrappers)
                  | key <- exportKeys, any ((== key) . coreFunctionName) lowered ]
              }
        Nothing -> LowerRefused [nativeRefusal (moduleSpan parsed) "this program"]
      refusals -> LowerRefused refusals

    tableIndex :: CoreFunction -> Int
    tableIndex function = case [index | (index, (name, _)) <- zip [0 ..] table, name == coreFunctionName function] of
      index : _ -> index
      [] -> 0

{-| At a C boundary the owning thread runs the cold task to completion. Await
    through ordinary Core so result crossing and task cleanup use the same
    paths as a synchronous export and Pudu's own await. -}
awaitExport :: Function -> CoreFunction -> CoreType -> CoreFunction
awaitExport declaration target answer =
  CoreFunction ("::export::" <> coreFunctionName target) parameters answer
    (CoreBlock [] (Just (CoreExpression at answer (CoreCallValue task []))))
  where
    parameters = coreFunctionParameters target
    at = locatedSpan (functionName declaration)
    arguments =
      [ CoreExpression at (coreLocalType local) (CoreReadLocal local)
      | CoreParameter local _ <- parameters ]
    task = CoreExpression at (coreFunctionResult target) (CoreCall (coreFunctionName target) arguments)
