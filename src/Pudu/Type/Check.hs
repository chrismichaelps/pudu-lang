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
import Pudu.Type.Check.Statement (FunctionRole (..), StatementNeeds (..))
import qualified Pudu.Type.Check.Statement as Statement
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
{-| What a statement needs of what it contains, tied here with the other half.

    Checking is one recursion written across several modules, and these two
    records are the knot: an expression reaches a block, a block reaches
    expressions and declarations, and a declaration reaches blocks again. -}
statementNeeds :: StatementNeeds
statementNeeds =
  StatementNeeds
    { statementExpression = checkExpression
    , statementDeclaration = checkDeclaration
    , statementFunction = checkFunctionWith
    }

checkBlock :: DeclaredTypes -> [Text] -> Located Block -> Checker Type
checkBlock = Statement.checkBlock statementNeeds

checkMember
  :: DeclaredTypes
  -> [Text]
  -> [(Text, [NominalId])]
  -> Maybe NominalId
  -> Located Function
  -> Checker ()
checkMember = Statement.checkMember statementNeeds

checkAgainst :: DeclaredTypes -> [Text] -> Type -> Located Expression -> Checker Type
checkAgainst = Statement.checkAgainst statementNeeds

checkBlockAgainst :: DeclaredTypes -> [Text] -> Type -> Located Block -> Checker Type
checkBlockAgainst = Statement.checkBlockAgainst statementNeeds

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
