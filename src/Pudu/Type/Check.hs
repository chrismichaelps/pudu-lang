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
  ( Capability (..)
  , Block (..)
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
  , ambiguousProviders
  , UnsafeFrame (..)
  , enterUnsafe
  , insideUnsafe
  , leaveUnsafe
  , unsafeFunctionCapabilities
  , useCapability
  , useUnsafeRegion
  , warn
  , recordUnsafeFunction
  , recordComptimeFunction
  , isComptimeFunction
  , inComptime
  , withComptime
  , lookupField
  , lookupName
  , recordExpression
  , report
  , withRigidBounds
  , validateIntegerLiteralsSince
  , runChecker
  , withDeclared
  )
import Pudu.Type.Check.Pattern (bindPattern)
import Pudu.Type.Check.Coherence (checkCoherence)
import Pudu.Type.Check.Rule
  ( awaitType
  , binaryType
  , enclosingFunctionType
  , enclosingReturnType
  , instantiate
  , callType
  , elementType
  , literalType
  , memberType
  , nameType
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
  , methodScheme
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
  , nominalKey
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
  let (types, schemes, diagnostics) = checkModuleDetailed imported moduleValue
   in schemes `seq` (types, diagnostics)

{-| Everything one check produced: the type of each expression, the scheme the
    module frame ended with for each declared name, and the diagnostics.

    Tooling that documents or searches a module needs the schemes, and asking
    it to re-derive them from the written syntax would let its answers drift
    from the compiler's. -}
checkModuleDetailed
  :: ImportTypes -> Module -> ([((Int, Int), Type)], [(Text, Scheme)], [Diagnostic])
checkModuleDetailed imported moduleValue =
  let products = runChecker (checkUnit imported moduleValue)
   in (producedTypes products, producedSchemes products, producedDiagnostics products)

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
  FunctionDeclaration value -> checkFunctionWith ModuleScopeFunction declared Nothing value
  TraitDeclaration value ->
    let name = locatedValue (traitName value)
        identity = Map.findWithDefault (NominalId Nothing name) name (declaredNames declared)
     in do
       when (traitVisibility value == Exported) $
         mapM_ (requireInterfaceAnnotations "exported trait member" . locatedValue) (traitMembers value)
       mapM_ (checkMember (traitAliases declared) (Just identity)) (traitMembers value)
  ImplDeclaration value ->
    do
      mapM_ (requireInterfaceAnnotations "implementation method" . locatedValue) (implFunctions value)
      mapM_ (checkMember (implAliases declared value) Nothing) (implFunctions value)
  _ -> pure ()

{-| Check a trait member with a rigid `Self` bound, or an implementation member
    with `Self` aliased to its canonical target. -}
checkMember :: DeclaredTypes -> Maybe NominalId -> Located Function -> Checker ()
checkMember declared selfBound (Located _ value) =
  checkFunctionWith MemberFunction declared selfBound value

{-| @Type.Check.FunctionRole — whether a function owns the module-scope name it
    is written under.

    A member does not: its scheme is recorded under a qualified key, and the
    plain name may belong to an unrelated free function in the same module.
    Tying a member's body to whatever that name happens to hold would unify two
    signatures that were never meant to meet. -}
data FunctionRole = ModuleScopeFunction | MemberFunction
  deriving stock (Eq, Show)

{-| `Self` inside a trait is the implementing type, which is unknown while the
    trait itself is checked, so it stays a rigid parameter there. -}
traitAliases :: DeclaredTypes -> DeclaredTypes
traitAliases = id

{-| Check a function body against its declared result. Exported signatures are
    annotated interfaces; a trait member receives its canonical trait as the
    rigid `Self` bound used by default-body method calls. -}
checkFunctionWith :: FunctionRole -> DeclaredTypes -> Maybe NominalId -> Function -> Checker ()
checkFunctionWith role declared selfBound value = do
  let rigid = functionRigid value <> foldMap selfRigid selfBound
      bounds = declareBounds declared value <> foldMap selfBoundAsBound selfBound
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
          BlockBody block -> checkBlock declared rigid block
          ExpressionBody expression -> checkExpression declared rigid expression
        {-| A function's unsafety is a contract its callers uphold, not a use
            its body has to justify, so leaving the body's region reports
            nothing. Only an explicit `unsafe { ... }` earns that warning. -}
        mapM_ (const (leaveUnsafe >> pure ())) (functionUnsafe value)
        _ <- unify bodySpan result actual
        pure ()
    finalizeIntegerLiterals
    dischargeObligations

{-| Unify a body's signature with the one the module already holds for the
    name, position by position.

    Only a signature of the same arity is tied: a mismatch there is a defect
    the declaration pass already reported, and unifying through it would
    produce a second, more confusing message. -}
adoptDeclaredSignature :: Function -> [Type] -> Type -> Scheme -> Checker ()
adoptDeclaredSignature value inputs result scheme = case schemeType scheme of
  FunctionTypeValue _ declaredInputs declaredResult
    | length declaredInputs == length inputs -> do
        mapM_ tie (zip declaredInputs inputs)
        tie (declaredResult, result)
  _ -> pure ()
 where
  headSpan = locatedSpan (functionName value)
  tie (left, right) = () <$ unify headSpan left right

{-| The constant an index expression names, when it names one.

    A tuple's members have different types, so indexing one is only meaningful
    at a known position. Everything else — an array, a string, a computed index
    — does not care, and reports `Nothing`. -}
literalIndex :: Located Expression -> Maybe Integer
literalIndex (Located _ expression) = case expression of
  LiteralExpression (Tree.IntegerValue text) ->
    parsedIntegerValue <$> parseIntegerLiteral text
  _ -> Nothing

{-| Type a function literal.

    The literal is checked exactly like a declaration's body — its parameters
    bound, its result unified with what the body produced — and answers with the
    function type a caller sees. Sharing the path is what keeps a literal and a
    declaration from drifting into two dialects of the same thing.

    A literal is not generalised. Its type is fixed at the point it is written,
    so a literal used at two types is an error the reader can see, rather than a
    silent second instantiation of something they wrote once. Generalisation
    belongs to a declaration, which has a name to attach it to. -}
lambdaType :: DeclaredTypes -> [Text] -> Function -> Checker Type
lambdaType declared rigid value = inTypeScopeWith $ do
  inputs <- mapM (bindParameter declared rigid) (functionParameters value)
  result <- formOptionalType declared rigid (functionReturn value)
  let signature = FunctionTypeValue (functionAsync value) inputs result
  bindName selfName (monotype signature)
  case functionBody value of
    Nothing -> pure ()
    Just (Located bodySpan body) -> do
      actual <- case body of
        BlockBody block -> checkBlock declared rigid block
        ExpressionBody expression -> checkExpression declared rigid expression
      _ <- unify bodySpan result actual
      pure ()
  zonk signature

{-| The type a borrow refers to, following as many references as were written.

    A `&&T` is unusual but writable, and stopping after one would report a
    confusing mismatch against a type the reader never intended to match on. -}
throughBorrow :: Type -> Checker Type
throughBorrow typeValue = do
  resolved <- zonk typeValue
  case resolved of
    ReferenceTypeValue _ referent -> throughBorrow referent
    _ -> pure resolved

{-| Warn when a statement throws away a value that is the whole point of the
    call that produced it.

    A built-in collection method never mutates its receiver; it returns a new
    collection. So `items.push(value)` written as a statement does nothing at
    all, and does it silently — the statement type-checks, the program runs, and
    the array is unchanged. This is not a style preference: there is no reading
    of that line under which it is correct.

    The check is deliberately narrow. It fires only for the closed set of
    built-in methods the compiler already knows the semantics of, on a receiver
    the checker has confirmed is a collection. A general "unused result" warning
    would need to know which functions are pure, which Pudu does not track, and
    guessing would either miss this case or bury it in noise. -}
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

{-| The built-in methods that answer with a new collection rather than changing
    the one they were given. `length`, `get`, `indexOf`, and `contains` are
    absent because discarding an answer to a question is merely pointless, not
    wrong: a reader who wrote it was asking, and the compiler has nothing to
    tell them that the line does not already say. -}
nonMutatingMethods :: [Text]
nonMutatingMethods =
  ["push", "pop", "insert", "remove", "slice", "reverse", "map", "filter"]

{-| The bound a trait member adds: `Self` satisfies the trait it belongs to,
    which lets a default body call other trait methods on `self`. -}
selfBoundAsBound :: NominalId -> [(Text, [NominalId])]
selfBoundAsBound traitName = [("Self", [traitName])]

{-| `Self` is rigid inside a trait member so that `formType` produces
    `RigidType "Self"` rather than `NominalType "Self"`, routing method
    calls through `rigidMethod` and the trait bound installed by
    `selfBoundAsBound`. -}
selfRigid :: NominalId -> [Text]
selfRigid _ = ["Self"]

selfName :: Text
selfName = "__return"

requireFunctionAnnotations :: Function -> Checker ()
requireFunctionAnnotations value
  | functionVisibility value /= Exported && not (functionAsync value) = pure ()
  | otherwise = do
      mapM_ requireParameter (functionParameters value)
      case functionReturn value of
        Just _ -> pure ()
        Nothing ->
          report "E3010" (locatedSpan (functionName value))
            (functionKind <> " function " <> locatedValue (functionName value) <> " needs a return type")
            (Just returnHelp)
 where
  functionKind
    | functionVisibility value == Exported = "exported"
    | otherwise = "async"
  returnHelp
    | functionVisibility value == Exported =
        "annotate the return type; an exported signature is read without its body"
    | otherwise =
        "annotate the return type so callers can form Task[S, E] without inspecting the body"
  requireParameter (Located parameterSpan parameter) = case Tree.parameterType parameter of
    Just _ -> pure ()
    Nothing ->
      report "E3010" parameterSpan
        (functionKind <> " parameter " <> locatedValue (Tree.parameterName parameter) <> " needs a type")
        (Just parameterHelp)
  parameterHelp
    | functionVisibility value == Exported = "annotate every parameter of an exported function"
    | otherwise = "annotate every parameter of an async function so calls do not determine its contract"

requireInterfaceAnnotations :: Text -> Function -> Checker ()
requireInterfaceAnnotations kind value = do
  mapM_ requireParameter (functionParameters value)
  case functionReturn value of
    Just _ -> pure ()
    Nothing ->
      report "E3010" (locatedSpan (functionName value))
        (kind <> " " <> locatedValue (functionName value) <> " needs a return type")
        (Just "annotate the complete signature because importers read it without its body")
 where
  requireParameter (Located parameterSpan parameter) = case Tree.parameterType parameter of
    Just _ -> pure ()
    Nothing ->
      report "E3010" parameterSpan
        (kind <> " parameter " <> locatedValue (Tree.parameterName parameter) <> " needs a type")
        (Just "annotate every interface-carried parameter")

bindParameter :: DeclaredTypes -> [Text] -> Located Parameter -> Checker Type
bindParameter declared rigid (Located _ parameter) = do
  formed <- formOptionalType declared rigid (Tree.parameterType parameter)
  case Tree.parameterDefault parameter of
    Nothing -> pure ()
    Just expression -> do
      actual <- checkExpression declared rigid expression
      _ <- unify (locatedSpan expression) formed actual
      pure ()
  bindName (locatedValue (Tree.parameterName parameter)) (monotype formed)
  pure formed

{-| A block's type is its trailing expression, or unit when it has none. -}
checkBlock :: DeclaredTypes -> [Text] -> Located Block -> Checker Type
checkBlock declared rigid (Located _ block) = do
  mapM_ (checkStatement declared rigid) (blockStatements block)
  case blockResult block of
    Nothing -> pure UnitTypeValue
    Just expression -> checkExpression declared rigid expression

checkStatement :: DeclaredTypes -> [Text] -> Located Statement -> Checker ()
checkStatement declared rigid (Located _ statement) = case statement of
  DeclarationStatement (Located _ (BindingDeclaration _ _ name annotation value)) -> do
    expected <- formOptionalType declared rigid annotation
    actual <- checkExpression declared rigid value
    unified <- unify (locatedSpan value) expected actual
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
  BreakStatement -> pure ()
  ContinueStatement -> pure ()
  InvalidStatement -> pure ()

{-| A member in callee position prefers a method over a field of the same
    name, because `value.name()` reads as a call and a field would have to be
    parenthesized to be called anyway. -}
checkCallee :: DeclaredTypes -> [Text] -> Located Expression -> Checker Type
checkCallee declared rigid located@(Located calleeSpan expression) = case expression of
  MemberExpression target member -> do
    named <- qualifiedByName declared calleeSpan (locatedValue target) (locatedValue member)
    qualified <- case named of
      Just found -> pure (Just found)
      Nothing -> qualifiedMemberType calleeSpan (locatedValue target) (locatedValue member)
    case qualified of
      Just instantiated -> do
        recordExpression calleeSpan instantiated
        pure instantiated
      Nothing -> do
        targetType <- checkExpression declared rigid target
        resolved <- zonk targetType
        method <- methodScheme calleeSpan resolved (locatedValue member)
        case method of
          Nothing -> checkExpression declared rigid located
          Just scheme -> do
            instantiated <- instantiate calleeSpan scheme
            let applied = case instantiated of
                  FunctionTypeValue asynchronous (_ : rest) result ->
                    FunctionTypeValue asynchronous rest result
                  other -> other
            recordExpression calleeSpan applied
            pure applied
  _ -> checkExpression declared rigid located

{-| A compile-time function runs in an evaluator with no IO, environment, time,
    randomness, unsafe, or task operations, so the shapes that could reach one
    are refused at the declaration rather than discovered when it runs. -}
requireComptimePurity :: Function -> Checker ()
requireComptimePurity value
  | not (functionComptime value) = pure ()
  | otherwise = do
      when (functionAsync value) $
        report "E3025" nameSpan
          ("comptime function " <> name <> " cannot be async")
          (Just "compile-time evaluation excludes task operations")
      case functionUnsafe value of
        Nothing -> pure ()
        Just _ ->
          report "E3025" nameSpan
            ("comptime function " <> name <> " cannot be unsafe")
            (Just "compile-time evaluation excludes unchecked operations")
 where
  name = locatedValue (functionName value)
  nameSpan = locatedSpan (functionName value)

{-| A compile-time body may call only other compile-time functions. The
    guarantee has to be transitive, or a pure-looking function could reach an
    arbitrary one and the evaluator would meet it at compile time. -}
checkComptimeCall :: Span -> Located Expression -> Checker ()
checkComptimeCall spanValue callee = do
  inside <- inComptime
  when inside $ case locatedValue callee of
    NameExpression (name NonEmpty.:| []) -> do
      comptime <- isComptimeFunction name
      builtin <- pure (name `elem` comptimeBuiltins)
      unless (comptime || builtin) $
        report "E3025" spanValue
          ("comptime function cannot call " <> name)
          (Just "declare the callee comptime, or move the call out of compile-time code")
    _ -> pure ()

{-| Names a compile-time body may reach that are not user declarations. -}
comptimeBuiltins :: [Text]
comptimeBuiltins = ["Some", "None", "Ok", "Err", "panic", "charFromCode"]

{-| A granted capability that the region never reached for is noise: it widens
    the audited surface without buying anything, so leaving the region reports
    it. -}
reportUnusedCapabilities :: Span -> Checker ()
reportUnusedCapabilities spanValue = do
  frame <- leaveUnsafe
  case frame of
    Nothing -> pure ()
    Just found -> do
      let granted = frameGranted found
          unused = [capability | capability <- granted, capability `notElem` frameUsed found]
      if null granted
        then
          when (null (frameUsed found)) $
            warn "W3001" spanValue "this unsafe region grants abilities nothing in it uses"
              (Just "remove the unsafe region, or name the capabilities the code needs")
        else
          unless (null unused) $
            warn "W3001" spanValue
              ("unsafe region grants unused " <> Text.intercalate ", " (map capabilityName unused))
              (Just "drop the capabilities the region does not need")

capabilityName :: Capability -> Text
capabilityName capability = case capability of
  RawCapability -> "raw"
  ForeignCapability -> "foreign"
  UncheckedCapability -> "unchecked"
  NullCapability -> "null"

{-| Calling an unsafe function requires an unsafe context that grants what the
    declaration asked for. A blanket declaration requires only that some region
    is open; a declaration that names capabilities requires each of them, which
    is what makes the requirement auditable rather than all-or-nothing. -}
checkUnsafeCall :: Span -> Located Expression -> Checker ()
checkUnsafeCall spanValue callee = case locatedValue callee of
  NameExpression (name NonEmpty.:| []) -> do
    declaredCapabilities <- unsafeFunctionCapabilities name
    case declaredCapabilities of
      Nothing -> pure ()
      Just [] -> do
        open <- insideUnsafe
        if open
          then useUnsafeRegion
          else
            report "E3023" spanValue
              ("unsafe function " <> name <> " called outside an unsafe region")
              (Just "wrap the call in unsafe { ... }, or declare the caller unsafe")
      Just required -> mapM_ (requireCapability spanValue name) required
  _ -> pure ()

requireCapability :: Span -> Text -> Capability -> Checker ()
requireCapability spanValue name capability = do
  granted <- useCapability capability
  unless granted $
    report "E3023" spanValue
      ( "unsafe function " <> name <> " needs the "
          <> capabilityName capability <> " capability here"
      )
      ( Just
          ( "wrap the call in unsafe(" <> capabilityName capability
              <> ") { ... }, or declare the caller with that capability"
          )
      )

{-| A callee written as `Name.member` may select a method by the trait that
    declares it or by the type that implements it. The written name is mapped to
    the declaration it identifies before the method key is built, so a local
    declaration and an imported one are reached the same way. -}
qualifiedByName
  :: DeclaredTypes -> Span -> Expression -> Text -> Checker (Maybe Type)
qualifiedByName declared spanValue target member = case target of
  NameExpression (first NonEmpty.:| []) -> case Map.lookup first (declaredNames declared) of
    Nothing -> pure Nothing
    Just identity -> do
      let key = nominalKey identity <> "." <> member
      providers <- ambiguousProviders key
      case providers of
        _ : _ -> do
          report "E3013" spanValue
            (member <> " is ambiguous for " <> nominalName identity)
            ( Just
                ( "name the trait instead: "
                    <> Text.intercalate " or "
                      [nominalName provider <> "." <> member <> "(value)" | provider <- providers]
                )
            )
          pure (Just ErrorType)
        [] -> do
          found <- lookupName key
          case found of
            Nothing -> pure Nothing
            Just scheme -> Just <$> instantiate spanValue scheme
  _ -> pure Nothing

{-| Check one expression and record the type it was given, so tooling can
    report it later. -}
checkExpression :: DeclaredTypes -> [Text] -> Located Expression -> Checker Type
checkExpression declared rigid (Located spanValue expression) = do
  typeValue <- inferExpression declared rigid spanValue expression
  resolved <- zonk typeValue
  recordExpression spanValue resolved
  pure typeValue

inferExpression :: DeclaredTypes -> [Text] -> Span -> Expression -> Checker Type
inferExpression declared rigid spanValue expression = case expression of
  LiteralExpression literal -> literalType spanValue literal
  NameExpression names -> nameType spanValue names
  UnaryExpression operator operand -> do
    actual <- checkExpression declared rigid operand
    unaryType spanValue operator actual
  BinaryExpression left operator right -> do
    leftType <- checkExpression declared rigid left
    rightType <- checkExpression declared rigid right
    binaryType spanValue operator leftType rightType
  CallExpression callee arguments -> do
    checkUnsafeCall spanValue callee
    checkComptimeCall spanValue callee
    calleeType <- checkCallee declared rigid callee
    argumentTypes <- mapM (checkExpression declared rigid) arguments
    callType spanValue calleeType argumentTypes
  MemberExpression target member -> do
    qualified <- qualifiedMemberType spanValue (locatedValue target) (locatedValue member)
    case qualified of
      Just value -> pure value
      Nothing -> do
        targetType <- checkExpression declared rigid target
        memberType spanValue targetType (locatedValue member)
  IndexExpression target index -> do
    targetType <- checkExpression declared rigid target
    indexType <- checkExpression declared rigid index
    _ <- unify (locatedSpan index) integerType indexType
    elementType spanValue (literalIndex index) targetType
  TryExpression target -> do
    checkpoint <- integerLiteralCheckpoint
    targetType <- checkExpression declared rigid target
    finalizeIntegerLiteralsSince checkpoint
    resolvedTarget <- zonk targetType
    declaredResult <- enclosingReturnType selfName
    tryType spanValue resolvedTarget declaredResult
  AwaitExpression target -> do
    checkpoint <- integerLiteralCheckpoint
    targetType <- checkExpression declared rigid target
    finalizeIntegerLiteralsSince checkpoint
    resolvedTarget <- zonk targetType
    (asynchronous, declaredResult) <- enclosingFunctionType selfName
    awaitType spanValue asynchronous resolvedTarget declaredResult
  TupleExpression members -> TupleTypeValue <$> mapM (checkExpression declared rigid) members
  ArrayExpression members -> do
    elementTypes <- mapM (checkExpression declared rigid) members
    inferredElementType <- case elementTypes of
      [] -> freshVariable
      first : rest -> foldM (unify spanValue) first rest
    pure (NominalType "Array" [inferredElementType])
  MacroCall _ _ -> pure ErrorType
  LambdaExpression value -> lambdaType declared rigid value
  ScopeExpression body -> do
    (asynchronous, _) <- enclosingFunctionType selfName
    unless asynchronous $
      report "E3026" spanValue "a structured scope needs an async function"
        (Just "declare the enclosing function async; a scope joins the tasks it starts")
    checkBlock declared rigid body
  UnsafeExpression capabilities body -> do
    enterUnsafe (map locatedValue capabilities)
    bodyType <- checkBlock declared rigid body
    reportUnusedCapabilities spanValue
    pure bodyType
  RecordExpression path fields -> recordType declared rigid spanValue path fields
  BlockExpression block -> checkBlock declared rigid block
  IfExpression condition thenBlock elseBranch -> do
    conditionCheckpoint <- integerLiteralCheckpoint
    conditionType <- checkExpression declared rigid condition
    _ <- unify (locatedSpan condition) boolType conditionType
    validateIntegerLiteralsSince conditionCheckpoint
    branchCheckpoint <- integerLiteralCheckpoint
    thenType <- checkBlock declared rigid thenBlock
    case elseBranch of
      Nothing -> do
        finalizeIntegerLiteralsSince branchCheckpoint
        pure UnitTypeValue
      Just branch -> do
        elseType <- checkExpression declared rigid branch
        unified <- unify spanValue thenType elseType
        validateIntegerLiteralsSince branchCheckpoint
        resolvedThen <- zonk thenType
        resolvedElse <- zonk elseType
        case (resolvedThen, resolvedElse) of
          (ErrorType, _) -> pure ErrorType
          (_, ErrorType) -> pure ErrorType
          _ -> zonk unified
  MatchExpression scrutinee arms -> do
    subjectCheckpoint <- integerLiteralCheckpoint
    borrowed <- checkExpression declared rigid scrutinee
    {-| A match reads its subject; it does not consume it. Looking through a
        borrow is what lets a function take `&Option[T]` and still match on it,
        and every language with both references and patterns does the same. A
        pattern that binds by value from a borrowed subject is an ownership
        question, and ownership checking is where it belongs — not here, where
        the only available answer would be to refuse the match entirely. -}
    subjectType <- throughBorrow borrowed
    subjectEnd <- integerLiteralCheckpoint
    result <- checkArms declared rigid spanValue subjectType arms
    finalizeIntegerLiteralsBetween subjectCheckpoint subjectEnd
    resolvedSubject <- zonk subjectType
    checkExhaustive spanValue resolvedSubject arms
    zonk result
  WhileExpression condition body -> do
    conditionCheckpoint <- integerLiteralCheckpoint
    conditionType <- checkExpression declared rigid condition
    _ <- unify (locatedSpan condition) boolType conditionType
    validateIntegerLiteralsSince conditionCheckpoint
    _ <- checkBlock declared rigid body
    pure UnitTypeValue
  LoopExpression body -> do
    _ <- checkBlock declared rigid body
    pure UnitTypeValue
  ForExpression binder iterated body -> do
    _ <- checkExpression declared rigid iterated
    inTypeScope $ do
      element <- freshVariable
      bindPattern declared rigid binder element
      checkBlock declared rigid body
    pure UnitTypeValue
  InvalidExpression -> pure ErrorType

{-| A record construction is checked field by field against its declaration,
    and every declared field must be supplied. -}
recordType
  :: DeclaredTypes -> [Text] -> Span -> ModuleName -> [Located FieldInit] -> Checker Type
recordType declared rigid spanValue path fields = do
  let name = NonEmpty.last (moduleNameSegments path)
      identity = Map.findWithDefault (NominalId Nothing (moduleNameText path))
        (moduleNameText path) (declaredNames declared)
  declaredFieldTypes <- lookupField identity
  case declaredFieldTypes of
    Nothing -> do
      report "E3007" spanValue (name <> " is not a record type")
        (Just "construct a record whose type declares fields")
      mapM_ (checkFieldInit declared rigid) fields
      pure ErrorType
    Just expected -> do
      mapM_ (checkField declared rigid expected) fields
      let supplied = map (locatedValue . fieldInitName . locatedValue) fields
          missing = [fieldName | (fieldName, _) <- expected, fieldName `notElem` supplied]
      case missing of
        [] -> pure ()
        _ ->
          report "E3008" spanValue
            (name <> " construction is missing " <> Text.intercalate ", " missing)
            (Just "supply every declared field")
      pure (NominalType identity [])

checkField
  :: DeclaredTypes -> [Text] -> [(Text, Type)] -> Located FieldInit -> Checker ()
checkField declared rigid expected located@(Located fieldSpan field) = do
  actual <- checkFieldInit declared rigid located
  let name = locatedValue (fieldInitName field)
  case lookup name expected of
    Nothing ->
      report "E3005" fieldSpan ("no declared field " <> name)
        (Just "check the field name against the type declaration")
    Just declaredType -> do
      _ <- unify fieldSpan declaredType actual
      pure ()

checkFieldInit :: DeclaredTypes -> [Text] -> Located FieldInit -> Checker Type
checkFieldInit declared rigid (Located fieldSpan field) = case fieldInitValue field of
  Just value -> checkExpression declared rigid value
  Nothing -> nameType fieldSpan (locatedValue (fieldInitName field) NonEmpty.:| [])

checkArms :: DeclaredTypes -> [Text] -> Span -> Type -> [Located MatchArm] -> Checker Type
checkArms declared rigid spanValue subjectType arms = case arms of
  [] -> pure ErrorType
  _ -> do
    checkpoint <- integerLiteralCheckpoint
    types <- mapM checkArm arms
    unified <- case types of
      [] -> pure ErrorType
      first : rest -> foldUnify first rest
    validateIntegerLiteralsSince checkpoint
    resolved <- mapM zonk types
    if ErrorType `elem` resolved then pure ErrorType else zonk unified
 where
  checkArm (Located _ arm) = do
    result <- freshVariable
    inTypeScope $ do
      bindPattern declared rigid (armPattern arm) subjectType
      case armGuard arm of
        Nothing -> pure ()
        Just guard -> do
          guardType <- checkExpression declared rigid guard
          _ <- unify (locatedSpan guard) boolType guardType
          pure ()
      bodyType <- checkExpression declared rigid (armBody arm)
      _ <- unify (locatedSpan (armBody arm)) result bodyType
      pure ()
    pure result
  foldUnify current rest = case rest of
    [] -> pure current
    next : remaining -> do
      unified <- unify spanValue current next
      foldUnify unified remaining
