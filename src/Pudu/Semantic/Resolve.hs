{-| @Semantic.Resolve.Module — resolves names to symbols -}
module Pudu.Semantic.Resolve
  ( Resolution (..)
  , resolveModule
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Pudu.Diagnostic (Diagnostic)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Constraint (..)
  , Declaration (..)
  , Expression (..)
  , FieldDeclaration (..)
  , FieldPattern (..)
  , Function (..)
  , FunctionBody (..)
  , Impl (..)
  , Import (..)
  , MatchArm (..)
  , Module (..)
  , Parameter (..)
  , Pattern (..)
  , Statement (..)
  , Trait (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , TypeParam (..)
  , TypeSyntax (..)
  , Variant (..)
  , VariantPayload (..)
  , BindingKind (Mutable)
  , Visibility (Private)
  )
import Pudu.Semantic.Prelude
  ( isPreludeModule
  , preludeTypeNames
  , preludeValueNames
  , wiredInTypeNames
  )
import Pudu.Semantic.Resolve.Context
  ( Resolver
  , ResolverProducts (..)
  , declareBuiltin
  , declarePreludeName
  , declareNamed
  , inScope
  , recordVariantSymbol
  , resolveTypeName
  , resolveValueName
  , runResolver
  )
import Pudu.Semantic.Symbol (Namespace (..), Reference, Symbol (..), SymbolOrigin (..))
import Pudu.Source (Span)

{-| @Semantic.Resolve.Result — the symbol table and reference map later phases
    consume, separate from the diagnostics produced alongside them -}
data Resolution = Resolution
  { resolutionSymbols :: ![Symbol]
  , resolutionReferences :: ![Reference]
  , resolutionExports :: ![Symbol]
  }
  deriving stock (Eq, Show)

{-| Resolve one parsed module. The walk is two-pass at module scope so a
    declaration may reference one that appears later in the file. -}
resolveModule :: Module -> (Resolution, [Diagnostic])
resolveModule moduleValue =
  let products = runResolver (resolveUnit moduleValue)
      symbols = producedSymbols products
   in ( Resolution
          { resolutionSymbols = symbols
          , resolutionReferences = producedReferences products
          , resolutionExports = filter isExported symbols
          }
      , producedDiagnostics products
      )

isExported :: Symbol -> Bool
isExported symbol = symbolVisibility symbol /= Private && symbolOrigin symbol == ModuleOrigin

{-| Scope layering follows the same shape Haskell uses: wired-in names first,
    then the implicit prelude module, then the module's own imports and
    declarations. An inner layer shadows an outer one silently. -}
resolveUnit :: Module -> Resolver ()
resolveUnit moduleValue = do
  declareWiredIn
  inScope $ do
    declarePrelude (moduleImports moduleValue)
    inScope $ do
      mapM_ collectImport (moduleImports moduleValue)
      mapM_ collectDeclaration (moduleDeclarations moduleValue)
      mapM_ walkDeclaration (moduleDeclarations moduleValue)

declareWiredIn :: Resolver ()
declareWiredIn = mapM_ (declareBuiltin TypeSpace) wiredInTypeNames

{-| The implicit prelude import is suppressed by an explicit import of the same
    module, so a module that names it controls exactly what it takes. -}
declarePrelude :: [Located Import] -> Resolver ()
declarePrelude imports
  | any importsPrelude imports = pure ()
  | otherwise = do
      mapM_ (declarePreludeName TypeSpace) preludeTypeNames
      mapM_ (declarePreludeName ValueSpace) preludeValueNames

importsPrelude :: Located Import -> Bool
importsPrelude (Located _ value) = isPreludeModule (locatedValue (importModule value))

{-| Imports never re-export. An alias or selected item becomes one opaque
    external symbol in both namespaces, because which namespace it belongs to is
    only knowable once cross-module resolution exists. -}
collectImport :: Located Import -> Resolver ()
collectImport (Located spanValue value) = case importAlias value of
  Just alias -> external (locatedValue alias) (locatedSpan alias)
  Nothing -> case importItems value of
    [] -> external (lastSegment (locatedValue (importModule value))) spanValue
    items -> mapM_ (\item -> external (locatedValue item) (locatedSpan item)) items
 where
  external name nameSpan = do
    declareNamed ValueSpace ImportOrigin Private False (Located nameSpan name)
    declareNamed TypeSpace ImportOrigin Private False (Located nameSpan name)

lastSegment :: ModuleName -> Text
lastSegment (ModuleName segments) = case segments of
  first :| rest -> last (first : rest)

{-| Collect every module-scope declaration before walking any body, so module
    order cannot change what resolves. -}
collectDeclaration :: Located Declaration -> Resolver ()
collectDeclaration (Located _ declaration) = case declaration of
  BindingDeclaration visibility _ name _ _ ->
    declareNamed ValueSpace ModuleOrigin visibility False name
  FunctionDeclaration value ->
    declareNamed ValueSpace ModuleOrigin (functionVisibility value) False (functionName value)
  TypeDeclaration value -> do
    declareNamed TypeSpace ModuleOrigin (typeVisibility value) False (typeName value)
    collectVariants (typeDefinition value)
  TraitDeclaration value ->
    declareNamed TypeSpace ModuleOrigin (traitVisibility value) False (traitName value)
  ImplDeclaration _ -> pure ()
  InvalidDeclaration -> pure ()

{-| Variants live in their type's namespace, so they are recorded as symbols but
    are not bound as unqualified names. -}
collectVariants :: Located TypeDefinition -> Resolver ()
collectVariants (Located _ definition) = case definition of
  SumDefinition variants -> mapM_ recordVariant variants
  _ -> pure ()
 where
  recordVariant (Located _ variant) = recordVariantSymbol (variantName variant)

walkDeclaration :: Located Declaration -> Resolver ()
walkDeclaration (Located _ declaration) = case declaration of
  BindingDeclaration _ _ _ annotation value -> do
    mapM_ walkType annotation
    walkExpression value
  FunctionDeclaration value -> walkFunction value
  TypeDeclaration value -> inScope $ do
    mapM_ bindTypeParam (typeTypeParams value)
    walkDefinition (typeDefinition value)
  TraitDeclaration value -> inScope $ do
    mapM_ bindTypeParam (traitTypeParams value)
    bindSelf
    mapM_ walkConstraint (traitConstraints value)
    mapM_ (\member -> walkFunction (locatedValue member)) (traitMembers value)
  ImplDeclaration value -> inScope $ do
    mapM_ bindTypeParam (implTypeParams value)
    bindSelf
    walkType (implTrait value)
    walkType (implTarget value)
    mapM_ walkConstraint (implConstraints value)
    mapM_ (\member -> walkFunction (locatedValue member)) (implFunctions value)
  InvalidDeclaration -> pure ()

{-| A parameter is visible to the defaults of later parameters and to the body,
    which is exactly the left-to-right rule for default arguments. -}
walkFunction :: Function -> Resolver ()
walkFunction value = inScope $ do
  mapM_ bindTypeParam (functionTypeParams value)
  mapM_ bindParameter (functionParameters value)
  mapM_ walkType (functionReturn value)
  mapM_ walkConstraint (functionConstraints value)
  mapM_ walkBody (functionBody value)

bindParameter :: Located Parameter -> Resolver ()
bindParameter (Located _ parameter) = do
  mapM_ walkType (parameterType parameter)
  mapM_ walkExpression (parameterDefault parameter)
  declareNamed ValueSpace ParameterOrigin Private False (parameterName parameter)

bindTypeParam :: Located TypeParam -> Resolver ()
bindTypeParam (Located _ value) = do
  mapM_ walkType (typeParamBounds value)
  declareNamed TypeSpace TypeParamOrigin Private False (typeParamName value)

bindSelf :: Resolver ()
bindSelf = declareBuiltin TypeSpace "Self"

walkConstraint :: Located Constraint -> Resolver ()
walkConstraint (Located _ value) = do
  walkTypeName (constraintSubject value)
  mapM_ walkType (constraintBounds value)

walkTypeName :: Located Text -> Resolver ()
walkTypeName name = resolveTypeName (locatedSpan name) (locatedValue name)

walkBody :: Located FunctionBody -> Resolver ()
walkBody (Located _ body) = case body of
  BlockBody block -> walkBlock block
  ExpressionBody value -> walkExpression value

walkDefinition :: Located TypeDefinition -> Resolver ()
walkDefinition (Located _ definition) = case definition of
  RecordDefinition fields -> mapM_ walkField fields
  SumDefinition variants -> mapM_ walkVariant variants
  AliasDefinition aliased -> walkType aliased
  InvalidDefinition -> pure ()

walkField :: Located FieldDeclaration -> Resolver ()
walkField (Located _ field) = walkType (fieldType field)

walkVariant :: Located Variant -> Resolver ()
walkVariant (Located _ variant) = case variantPayload variant of
  UnitPayload -> pure ()
  TuplePayload members -> mapM_ walkType members
  RecordPayload fields -> mapM_ walkField fields

{-| A block binding takes effect after its own declaration, so an initializer
    sees the outer binding of the same name rather than the one being declared. -}
walkBlock :: Located Block -> Resolver ()
walkBlock (Located _ block) = inScope $ do
  mapM_ walkStatement (blockStatements block)
  mapM_ walkExpression (blockResult block)

walkStatement :: Located Statement -> Resolver ()
walkStatement (Located _ statement) = case statement of
  DeclarationStatement (Located _ (BindingDeclaration _ kind name annotation value)) -> do
    mapM_ walkType annotation
    walkExpression value
    declareNamed ValueSpace LocalOrigin Private (kind == Mutable) name
  DeclarationStatement other -> walkDeclaration other
  ExpressionStatement value -> walkExpression value
  ReturnStatement value -> mapM_ walkExpression value
  BreakStatement -> pure ()
  ContinueStatement -> pure ()
  InvalidStatement -> pure ()

walkExpression :: Located Expression -> Resolver ()
walkExpression (Located spanValue expression) = case expression of
  LiteralExpression _ -> pure ()
  NameExpression names -> resolveHead spanValue names
  UnaryExpression _ operand -> walkExpression operand
  BinaryExpression left _ right -> walkExpression left >> walkExpression right
  CallExpression callee arguments -> walkExpression callee >> mapM_ walkExpression arguments
  MemberExpression target _ -> walkExpression target
  IndexExpression target index -> walkExpression target >> walkExpression index
  TryExpression target -> walkExpression target
  AwaitExpression target -> walkExpression target
  BlockExpression block -> walkBlock block
  IfExpression condition thenBlock elseBranch -> do
    walkExpression condition
    walkBlock thenBlock
    mapM_ walkExpression elseBranch
  MatchExpression scrutinee arms -> do
    walkExpression scrutinee
    mapM_ walkArm arms
  WhileExpression condition body -> walkExpression condition >> walkBlock body
  LoopExpression body -> walkBlock body
  ForExpression binder iterated body -> do
    walkExpression iterated
    inScope $ do
      bindPattern binder
      walkBlock body
  InvalidExpression -> pure ()

walkArm :: Located MatchArm -> Resolver ()
walkArm (Located _ arm) = inScope $ do
  bindPattern (armPattern arm)
  mapM_ walkExpression (armGuard arm)
  walkExpression (armBody arm)

{-| Pattern bindings enter the arm's own frame; a constructor path is resolved
    in the type namespace, and its payload patterns bind in turn. -}
bindPattern :: Located Pattern -> Resolver ()
bindPattern (Located patternSpan value) = case value of
  WildcardPattern -> pure ()
  BindingPattern name -> declareNamed ValueSpace PatternOrigin Private False name
  LiteralPattern _ -> pure ()
  RangePattern{} -> pure ()
  TuplePattern members -> mapM_ bindPattern members
  ConstructorPattern path arguments -> do
    resolvePath patternSpan path
    mapM_ bindPattern arguments
  RecordPattern path fields _ -> do
    mapM_ (resolvePath patternSpan) path
    mapM_ bindFieldPattern fields
  AlternativePattern alternatives -> mapM_ bindPattern alternatives
  InvalidPattern -> pure ()

bindFieldPattern :: Located FieldPattern -> Resolver ()
bindFieldPattern (Located _ field) = case fieldPatternValue field of
  Just nested -> bindPattern nested
  Nothing -> declareNamed ValueSpace PatternOrigin Private False (fieldPatternName field)

walkType :: Located TypeSyntax -> Resolver ()
walkType (Located typeSpan value) = case value of
  NamedType path arguments -> do
    resolvePath typeSpan path
    mapM_ walkType arguments
  ReferenceType _ target -> walkType target
  TupleType members -> mapM_ walkType members
  FunctionType _ inputs result -> mapM_ walkType inputs >> walkType result
  UnitType -> pure ()
  InvalidType -> pure ()

{-| Only the first segment of a path is resolved. Later segments are member,
    field, or variant selections whose meaning requires types, so resolution
    neither invents nor rejects them. -}
resolveHead :: Span -> NonEmpty Text -> Resolver ()
resolveHead spanValue (first :| _) = resolveValueName spanValue first

resolvePath :: Span -> ModuleName -> Resolver ()
resolvePath spanValue (ModuleName (first :| _)) = resolveTypeName spanValue first

