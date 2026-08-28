{-| @Type.Check.Module — checks declarations, statements, and expressions -}
module Pudu.Type.Check
  ( checkModule
  , checkModuleDetailed
  , checkModuleWith
  ) where

import Control.Monad (foldM, unless, when)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.IntegerLiteral (ParsedInteger (..), parseIntegerLiteral)
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameSegments, moduleNameText)
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Declaration (..)
  , Expression (..)
  , FieldInit (..)
  , Function (..)
  , FunctionBody (..)
  , Impl (..)
  , MatchArm (..)
  , Module (..)
  , Parameter
  , Statement (..)
  , Trait (..)
  , TypeParam (..)
  , Visibility (Exported)
  )
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker
  , CheckerProducts (..)
  , DeclaredTypes (..)
  , bindName
  , finalizeIntegerLiterals
  , finalizeIntegerLiteralsBetween
  , finalizeIntegerLiteralsSince
  , freshVariable
  , inTypeScope
  , inTypeScopeWith
  , integerLiteralCheckpoint
  , LoopFrame (..)
  , enterLoop
  , enterUnsafe
  , leaveLoop
  , loopTarget
  , markLoopBroken
  , withoutLoops
  , leaveUnsafe
  , warn
  , recordUnsafeFunction
  , recordComptimeFunction
  , withComptime
  , lookupField
  , lookupVariant
  , lookupVariantFields
  , lookupTypeParams
  , lookupName
  , recordExpression
  , report
  , withRigidBounds
  , validateIntegerLiteralsSince
  , runChecker
  , withDeclared
  )
import Pudu.Type.Check.Pattern (bindPattern, freshFor, substituteRigid)
import Pudu.Type.Check.Iteration (iterationElement)
import Pudu.Type.Check.Safety
  ( checkComptimeCall
  , checkUnsafeCall
  , reportUnusedCapabilities
  , requireComptimePurity
  )
import Pudu.Type.Check.Call
  ( CheckExpression (..)
  , checkCallee
  , throughBorrow
  , traitQualifiedCall
  )
import Pudu.Type.Check.Coherence (checkCoherence)
import Pudu.Type.Check.Expression (CheckSurroundings (..))
import qualified Pudu.Type.Check.Expression as Expression
import Pudu.Type.Check.Record
  ( CheckValue (..)
  , namedVariantShape
  , recordType
  )
import Pudu.Type.Check.Signature
  ( adoptDeclaredSignature
  , nonMutatingMethods
  , requireFunctionAnnotations
  , requireInterfaceAnnotations
  , selfBoundAsBound
  , selfRigid
  , traitAliases
  )
import Pudu.Type.Check.Rule
  ( awaitType
  , binaryType
  , enclosingFunctionType
  , enclosingReturnType
  , instantiateWith
  , callType
  , elementType
  , literalType
  , memberType
  , nameType
  , selfName
  , namedVariantAsValue
  , qualifiedMemberType
  , tryType
  , unaryType
  )
import Pudu.Type.Check.Method
  ( declareBounds
  , declareMethods
  , declareBuiltinConstructors
  , declareTraitMembers
  , dischargeObligations
  , functionRigid
  , implAliases
  , implBounds
  , implRigid
  , traitBounds
  , traitRigid
  , traitTable
  )
import Pudu.Type.Exhaust (checkExhaustive)
import Pudu.Type.Formation
  ( collectDeclaredFrom
  , declaredParameterType
  , formOptionalType
  , formType
  )
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value
  ( NominalId (..)
  , Scheme (..)
  , monotype
  , polytype
  , Type (..)
  , boolType
  , integerType
  )
import Pudu.Type.Interface (ImportTypes)
import Pudu.Type.Check.Import (collectImportedDeclared, declareImportedTypes)

{-| Check one module. Signatures are collected before any body is checked, so a
    function may call one declared later without a forward declaration. -}
checkModule :: Module -> ([((Int, Int), Type)], [Diagnostic])
checkModule = checkModuleWith mempty

checkModuleWith :: ImportTypes -> Module -> ([((Int, Int), Type)], [Diagnostic])
checkModuleWith imported moduleValue =
  let (types, schemes, kinds, diagnostics) = checkModuleDetailed imported moduleValue
   in schemes `seq` kinds `seq` (types, diagnostics)

{-| Everything one check produced: the type of each expression, the scheme the
    module frame ended with for each declared name, and the diagnostics.

    Tooling that documents or searches a module needs the schemes, and asking
    it to re-derive them from the written syntax would let its answers drift
    from the compiler's. -}
checkModuleDetailed
  :: ImportTypes
  -> Module
  -> ([((Int, Int), Type)], [(Text, Scheme)], [(Span, Text)], [Diagnostic])
checkModuleDetailed imported moduleValue =
  let products = runChecker (checkUnit imported moduleValue)
   in ( producedTypes products
      , producedSchemes products
      , producedIntegerKinds products
      , producedDiagnostics products
      )

checkUnit :: ImportTypes -> Module -> Checker ()
checkUnit imported moduleValue = do
  dependencyDeclared <- collectImportedDeclared imported
  declared <- collectDeclaredFrom dependencyDeclared
    (locatedValue (moduleName moduleValue))
    (moduleDeclarations moduleValue)
  withDeclared declared
  declareBuiltinConstructors
  declareImportedTypes declared imported
  let traits = traitTable declared (moduleDeclarations moduleValue)
  mapM_ (declareSignature declared traits) (moduleDeclarations moduleValue)
  checkCoherence (moduleDeclarations moduleValue)
  mapM_ (checkDeclaration declared) (moduleDeclarations moduleValue)
  finalizeIntegerLiterals
  dischargeObligations

{-| Give every module-scope declaration a type before bodies are checked. -}
declareSignature
  :: DeclaredTypes -> Map.Map NominalId [Located Function] -> Located Declaration -> Checker ()
declareSignature declared traits (Located _ declaration) = case declaration of
  BindingDeclaration _ _ name annotation _ -> do
    formed <- formOptionalType declared [] annotation
    bindName (locatedValue name) (monotype formed)
  FunctionDeclaration value -> declareFunction declared value
  TypeDeclaration value -> declareConstructors declared value
  ImplDeclaration value -> declareMethods declared traits value
  TraitDeclaration value -> declareTraitMembers declared value
  _ -> pure ()
declareFunction :: DeclaredTypes -> Function -> Checker ()
declareFunction declared value = do
  let rigid = functionRigid value
  inputs <- mapM (declaredParameterType declared rigid) (functionParameters value)
  result <- formOptionalType declared rigid (functionReturn value)
  bindName (locatedValue (functionName value))
    ( polytype rigid (declareBounds declared value)
        (FunctionTypeValue (functionAsync value) inputs result)
    )
  case functionUnsafe value of
    Nothing -> pure ()
    Just capabilities ->
      recordUnsafeFunction (locatedValue (functionName value)) (map locatedValue capabilities)
  when (functionComptime value) (recordComptimeFunction (locatedValue (functionName value)))

{-| A sum's variants become constructors: a payload-carrying variant is a
    function to its own type, a unit variant is a value of it. -}
declareConstructors :: DeclaredTypes -> Tree.TypeDeclarationValue -> Checker ()
declareConstructors declared value = case locatedValue (Tree.typeDefinition value) of
  Tree.SumDefinition variants -> mapM_ declareVariant variants
  _ -> pure ()
 where
  ownerName = locatedValue (Tree.typeName value)
  owner = Map.findWithDefault (NominalId Nothing ownerName) ownerName (declaredNames declared)
  rigid = map (locatedValue . typeParamName . locatedValue) (Tree.typeTypeParams value)
  ownerType = NominalType owner (map RigidType rigid)
  declareVariant (Located _ variant) = do
    payload <- variantPayload declared rigid variant
    let name = locatedValue (Tree.variantName variant)
        scheme
          | null payload = polytype rigid [] ownerType
          | otherwise = polytype rigid [] (FunctionTypeValue False payload ownerType)
    bindName name scheme

variantPayload :: DeclaredTypes -> [Text] -> Tree.Variant -> Checker [Type]
variantPayload declared rigid variant = case Tree.variantPayload variant of
  Tree.UnitPayload -> pure []
  Tree.TuplePayload members -> mapM (formType declared rigid) members
  Tree.RecordPayload fields ->
    mapM (\(Located _ field) -> formType declared rigid (Tree.fieldType field)) fields

checkDeclaration :: DeclaredTypes -> Located Declaration -> Checker ()
checkDeclaration declared (Located _ declaration) = case declaration of
  BindingDeclaration visibility _ name annotation value -> do
    when (visibility == Exported && annotation == Nothing) $
      report "E3010" (locatedSpan name)
        ("exported binding " <> locatedValue name <> " needs a type annotation")
        (Just "annotate the exported binding so importers can check it without its body")
    expected <- formOptionalType declared [] annotation
    actual <- checkExpression declared [] value
    _ <- unify (locatedSpan value) expected actual
    bindName (locatedValue name) (monotype expected)
  FunctionDeclaration value -> checkFunctionWith ModuleScopeFunction declared [] [] Nothing value
  TraitDeclaration value ->
    let name = locatedValue (traitName value)
        identity = Map.findWithDefault (NominalId Nothing name) name (declaredNames declared)
     in do
       when (traitVisibility value == Exported) $
         mapM_ (requireInterfaceAnnotations "exported trait member" . locatedValue) (traitMembers value)
       mapM_
         (checkMember (traitAliases declared) (traitRigid value) (traitBounds declared value) (Just identity))
         (traitMembers value)
  ImplDeclaration value ->
    do
      mapM_ (requireInterfaceAnnotations "implementation method" . locatedValue) (implFunctions value)
      mapM_
        (checkMember (implAliases declared value) (implRigid value) (implBounds declared value) Nothing)
        (implFunctions value)
  _ -> pure ()

{-| Check a trait member with a rigid `Self` bound, or an implementation member
    with `Self` aliased to its canonical target. -}
checkMember
  :: DeclaredTypes
  -> [Text]
  -> [(Text, [NominalId])]
  -> Maybe NominalId
  -> Located Function
  -> Checker ()
checkMember declared enclosing enclosingBounds selfBound (Located _ value) =
  checkFunctionWith MemberFunction declared enclosing enclosingBounds selfBound value

{-| @Type.Check.FunctionRole — whether a function owns the module-scope name it
    is written under.

    A member does not: its scheme is recorded under a qualified key, and the
    plain name may belong to an unrelated free function in the same module.
    Tying a member's body to whatever that name happens to hold would unify two
    signatures that were never meant to meet. -}
data FunctionRole = ModuleScopeFunction | MemberFunction
  deriving stock (Eq, Show)

checkFunctionWith
  :: FunctionRole
  -> DeclaredTypes
  -> [Text]
  -> [(Text, [NominalId])]
  -> Maybe NominalId
  -> Function
  -> Checker ()
checkFunctionWith role declared enclosing enclosingBounds selfBound value = do
  {-| The declaration a member belongs to contributes its own type parameters.
      An implementation's `T` is rigid inside its methods for the same reason a
      function's is inside its body, and without it the annotation `-> T` was
      formed as a nominal type named `T` while `self.value` gave the real one,
      so the two disagreed while printing identically. -}
  let rigid = enclosing <> functionRigid value <> foldMap selfRigid selfBound
      bounds = enclosingBounds <> declareBounds declared value <> foldMap selfBoundAsBound selfBound
  requireFunctionAnnotations value
  requireComptimePurity value
  declaredScheme <- case role of
    ModuleScopeFunction -> lookupName (locatedValue (functionName value))
    MemberFunction -> pure Nothing
  withRigidBounds bounds $ withComptime (functionComptime value) $ inTypeScope $ do
    inputs <- mapM (bindParameter declared rigid) (functionParameters value)
    result <- formOptionalType declared rigid (functionReturn value)
    bindName selfName (monotype (FunctionTypeValue (functionAsync value) inputs result))
    {-| Tie the signature the module was given to the one this body is checked
        against. Without this the two hold separate variables for every
        position the declaration did not annotate, and whatever the body proves
        never reaches the name a caller — or a reader asking what the function
        is — actually sees.

        This unifies rather than replaces: the declared signature is still the
        one that was announced to the rest of the module, and a body that
        contradicts it must still fail against it. -}
    mapM_ (adoptDeclaredSignature value inputs result) declaredScheme
    case functionBody value of
      Nothing -> pure ()
      Just (Located bodySpan body) -> do
        {-| An unsafe function's body is itself an unsafe region granting what
            the declaration named, so the body may use those abilities without
            opening a region of its own. -}
        mapM_ (enterUnsafe . map locatedValue) (functionUnsafe value)
        actual <- case body of
          BlockBody block -> checkBlockAgainst declared rigid result block
          ExpressionBody expression -> checkAgainst declared rigid result expression
        {-| A function's unsafety is a contract its callers uphold, not a use
            its body has to justify, so leaving the body's region reports
            nothing. Only an explicit `unsafe { ... }` earns that warning. -}
        mapM_ (const (leaveUnsafe >> pure ())) (functionUnsafe value)
        _ <- unify bodySpan result actual
        pure ()
    finalizeIntegerLiterals
    dischargeObligations

reportDiscardedResult :: DeclaredTypes -> [Text] -> Located Expression -> Checker ()
reportDiscardedResult declared rigid (Located spanValue expression) = case expression of
  CallExpression callee _ -> case locatedValue callee of
    MemberExpression receiver member
      | locatedValue member `elem` nonMutatingMethods -> do
          receiverType <- checkExpression declared rigid receiver
          resolved <- zonk receiverType
          when (isCollection resolved) $
            warn "W3002"
              spanValue
              ( locatedValue member
                  <> " returns a new collection and this result is discarded"
              )
              ( Just
                  ( "assign it back, as in value = value."
                      <> locatedValue member
                      <> "(...), or remove the call"
                  )
              )
    _ -> pure ()
  _ -> pure ()
 where
  isCollection resolved = case resolved of
    NominalType identity _ -> nominalName identity `elem` ["Array", "Str"]
    ReferenceTypeValue _ inner -> isCollection inner
    _ -> False

bindParameter :: DeclaredTypes -> [Text] -> Located Parameter -> Checker Type
bindParameter declared rigid (Located _ parameter) = do
  formed <- formOptionalType declared rigid (Tree.parameterType parameter)
  case Tree.parameterDefault parameter of
    Nothing -> pure ()
    Just expression -> do
      actual <- checkExpression declared rigid expression
      _ <- unify (locatedSpan expression) formed actual
      pure ()
  {-| A parameter's name carries its declared type, for the reason a binding's
      does: an editor asked about `shape` should answer about `shape` rather
      than about the function it belongs to. -}
  recordExpression (locatedSpan (Tree.parameterName parameter)) formed
  bindName (locatedValue (Tree.parameterName parameter)) (monotype formed)
  pure formed

{-| A block's type is its trailing expression, or unit when it has none. -}
{-| What an expression needs of the constructs around it, tied once here.

    Checking is one recursion written across four modules, and this is the knot:
    an expression reaches a block, a pushed-down type, and a parameter binding,
    each of which reaches expressions again. -}
surroundings :: CheckSurroundings
surroundings =
  CheckSurroundings
    { aroundBlock = checkBlock
    , aroundAgainst = checkAgainst
    , aroundParameter = bindParameter
    }

{-| The type of an expression, with the surrounding constructs supplied. Every
    caller here reaches expressions through this rather than through the
    module, so the knot is tied in exactly one place. -}
checkExpression :: DeclaredTypes -> [Text] -> Located Expression -> Checker Type
checkExpression = Expression.checkExpression surroundings

checkBlock :: DeclaredTypes -> [Text] -> Located Block -> Checker Type
checkBlock declared rigid (Located _ block) = do
  mapM_ (checkStatement declared rigid) (blockStatements block)
  case blockResult block of
    Nothing -> pure UnitTypeValue
    Just expression -> checkExpression declared rigid expression

checkStatement :: DeclaredTypes -> [Text] -> Located Statement -> Checker ()
checkStatement declared rigid (Located spanValue statement) = case statement of
  DeclarationStatement (Located _ (BindingDeclaration _ _ name annotation value)) -> do
    expected <- formOptionalType declared rigid annotation
    actual <- case annotation of
      Just _ -> checkAgainst declared rigid expected value
      Nothing -> checkExpression declared rigid value
    unified <- unify (locatedSpan value) expected actual
    {-| The name a binding introduces carries the type it was given, so an
        editor asked about `text` in `let text = "hello"` can answer about
        `text`. Only uses were recorded before, and a reader points at the
        place a name is introduced at least as often as at a use of it. -}
    resolved <- zonk unified
    recordExpression (locatedSpan name) resolved
    bindName (locatedValue name) (monotype unified)
  DeclarationStatement other -> checkDeclaration declared other
  ExpressionStatement expression -> do
    _ <- checkExpression declared rigid expression
    reportDiscardedResult declared rigid expression
  ReturnStatement value -> do
    actual <- case value of
      Nothing -> pure UnitTypeValue
      Just expression -> checkExpression declared rigid expression
    expected <- enclosingReturnType selfName
    case value of
      Nothing -> pure ()
      Just expression -> do
        _ <- unify (locatedSpan expression) expected actual
        pure ()
  BreakStatement label value -> checkBreak declared rigid spanValue label value
  ContinueStatement _ -> pure ()
  InvalidStatement -> pure ()

{-| Check a `break`, against the loop it leaves.

    A `break` carrying a value must leave a `loop`: `while` and `for` finish on
    their own condition, so a value carried out of one would be produced on
    some runs and not others, and there is no type for that. Reported here
    rather than made to work, because the honest fix is a `loop` and saying so
    is more use than inventing a default.

    Every `break` leaving the same loop must carry the same type, which is what
    unifying against the loop's result variable enforces. -}
checkBreak
  :: DeclaredTypes
  -> [Text]
  -> Span
  -> Maybe (Located Text)
  -> Maybe (Located Expression)
  -> Checker ()
checkBreak declared rigid spanValue label value = do
  target <- loopTarget (fmap locatedValue label)
  markLoopBroken (fmap locatedValue label)
  case (target, value) of
    (_, Nothing) -> pure ()
    (Nothing, Just expression) -> do
      _ <- checkExpression declared rigid expression
      pure ()
    (Just frame, Just expression) -> do
      carried <- checkExpression declared rigid expression
      if frameCarries frame
        then do
          _ <- unify (locatedSpan expression) (frameResult frame) carried
          pure ()
        else
          report "E3029" spanValue "this loop cannot carry a value out of a break"
            ( Just
                ( "while and for finish when their own condition does, so a value "
                    <> "carried out would exist on some runs and not others; use loop"
                )
            )

checkAgainst :: DeclaredTypes -> [Text] -> Type -> Located Expression -> Checker Type
checkAgainst declared rigid expected located@(Located spanValue expression) = do
  resolved <- zonk expected
  if not (worthPushing resolved)
    then fallback
    else case expression of
      IfExpression condition thenBlock elseBranch -> do
        conditionType <- checkExpression declared rigid condition
        _ <- unify (locatedSpan condition) boolType conditionType
        _ <- checkBlockAgainst declared rigid resolved thenBlock
        mapM_ (checkAgainst declared rigid resolved) elseBranch
        recordExpression spanValue resolved
        pure resolved
      MatchExpression scrutinee arms -> do
        subject <- checkExpression declared rigid scrutinee
        resolvedSubject <- zonk subject
        mapM_ (checkArmAgainst declared rigid resolved resolvedSubject) arms
        checkExhaustive spanValue resolvedSubject arms
        recordExpression spanValue resolved
        pure resolved
      ArrayExpression members
        | NominalType identity [element] <- resolved
        , nominalName identity == "Array" -> do
            mapM_ (checkAgainst declared rigid element) members
            recordExpression spanValue resolved
            pure resolved
      BlockExpression block -> do
        _ <- checkBlockAgainst declared rigid resolved block
        recordExpression spanValue resolved
        pure resolved
      _ -> fallback
 where
  {-| Returning what `unify` produced, rather than the inferred type, is what
      keeps a failure from being reported twice: the caller unifies again
      against the same expectation, and `ErrorType` absorbs there. -}
  fallback = do
    actual <- checkExpression declared rigid located
    unify spanValue expected actual

  {-| Only a dynamic expectation changes an outcome, and pushing one inward
      costs a walk. Anything else is left to inference, which already handles
      it and produces the diagnostics readers are used to. -}
  worthPushing typeValue = case typeValue of
    DynamicTypeValue _ -> True
    NominalType _ arguments -> any worthPushing arguments
    TupleTypeValue members -> any worthPushing members
    ReferenceTypeValue _ target -> worthPushing target
    _ -> False

{-| A block checked against an expectation pushes it to the trailing
    expression, which is the block's value. -}
checkBlockAgainst :: DeclaredTypes -> [Text] -> Type -> Located Block -> Checker Type
checkBlockAgainst declared rigid expected (Located blockSpan block) = do
  mapM_ (checkStatement declared rigid) (blockStatements block)
  case blockResult block of
    Nothing -> do
      _ <- unify blockSpan expected UnitTypeValue
      pure UnitTypeValue
    Just expression -> checkAgainst declared rigid expected expression

checkArmAgainst
  :: DeclaredTypes -> [Text] -> Type -> Type -> Located MatchArm -> Checker ()
checkArmAgainst declared rigid expected subject (Located _ arm) = inTypeScope $ do
  bindPattern declared rigid (armPattern arm) subject
  mapM_ (checkGuard declared rigid) (armGuard arm)
  _ <- checkAgainst declared rigid expected (armBody arm)
  pure ()

checkGuard :: DeclaredTypes -> [Text] -> Located Expression -> Checker ()
checkGuard declared rigid guard = do
  guardType <- checkExpression declared rigid guard
  _ <- unify (locatedSpan guard) boolType guardType
  pure ()

{-| Check one expression and record the type it was given, so tooling can
    report it later. -}
{-| The way [[Type Check Call]] checks an expression.

    A call's arguments are expressions and an expression may be a call, so one
    direction has to be a capability rather than an import. This is that
    direction. -}