{-| @Repl.Describe.Module — describes what a session knows about a name -}
module Pudu.Repl.Describe
  ( declarationSummary
  , describeInstances
  , describeKind
  , describeKindLines
  , describeName
  , importSummary
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Capability (..)
  , Declaration (..)
  , FieldDeclaration (..)
  , Function (..)
  , Impl (..)
  , Macro (..)
  , MacroKind (..)
  , MacroParam (..)
  , Module (..)
  , Parameter (..)
  , BindingKind (..)
  , Import (..)
  , Trait (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , TypeParam (..)
  , TypeSyntax (..)
  , Variant (..)
  , VariantPayload (..)
  , Visibility (Exported)
  )

{-| Describe a name the way a reader asks about it: what it is, how it is
    written, and — for a type — which traits are implemented for it.

    The description is rendered from the session's own module, so it says what
    the session would compile rather than what a separate record remembers. -}
describeName :: Module -> Text -> [Text]
describeName moduleValue name =
  case concatMap (describeDeclaration name) (moduleDeclarations moduleValue) of
    [] -> foldMap wiredInDescription (wiredInArity name)
    found -> found <> implementationsFor moduleValue name
 where
  wiredInDescription arity =
    [ "type " <> name <> " -- provided by the compiler"
    , name <> " :: " <> arrowKind arity
    ]

describeDeclaration :: Text -> Located Declaration -> [Text]
describeDeclaration name (Located _ declaration) = case declaration of
  BindingDeclaration visibility _ boundName annotation _
    | locatedValue boundName == name ->
        [ exportPrefix visibility <> "const " <> name
            <> maybe Text.empty (\syntax -> ": " <> renderType syntax) annotation
        ]
  FunctionDeclaration value
    | locatedValue (functionName value) == name -> [renderSignature value]
  TypeDeclaration value
    | locatedValue (typeName value) == name -> [renderTypeDeclaration value]
  TraitDeclaration value
    | locatedValue (traitName value) == name ->
        ( exportPrefix (traitVisibility value) <> "trait " <> name
            <> renderTypeParams (traitTypeParams value)
        )
          : map (("  " <>) . renderSignature . locatedValue) (traitMembers value)
  MacroDeclaration value
    | locatedValue (macroName value) == name -> [renderMacro value]
  _ -> []

{-| Every trait implemented for a nominal type, in declaration order. -}
implementationsFor :: Module -> Text -> [Text]
implementationsFor moduleValue name =
  [ "impl " <> renderType (implTrait value) <> " for " <> renderType (implTarget value)
  | Located _ (ImplDeclaration value) <- moduleDeclarations moduleValue
  , targetName (implTarget value) == Just name
  ]

{-| Which traits a type implements, which is what `:instances` answers. -}
describeInstances :: Module -> Text -> [Text]
describeInstances = implementationsFor

{-| Report a type's arity the way a reader needs it: a nominal type applied to
    nothing, or a constructor that still expects arguments.

    Pudu has no kind system, so this reports the shape a type declaration
    promises rather than inventing one. -}
describeKind :: Module -> Text -> Maybe Text
describeKind moduleValue name = case declaredArity moduleValue name of
  Just arity -> Just (name <> " :: " <> arrowKind arity)
  Nothing -> (\arity -> name <> " :: " <> arrowKind arity) <$> wiredInArity name

declaredArity :: Module -> Text -> Maybe Int
declaredArity moduleValue name =
  case
    [ length (typeTypeParams value)
    | Located _ (TypeDeclaration value) <- moduleDeclarations moduleValue
    , locatedValue (typeName value) == name
    ]
      <> [ length (traitTypeParams value)
         | Located _ (TraitDeclaration value) <- moduleDeclarations moduleValue
         , locatedValue (traitName value) == name
         ]
    of
    arity : _ -> Just arity
    [] -> Nothing

{-| The arities the compiler wires in. A reader asking about `Option` is asking
    a real question, and answering it from the same list the checker uses keeps
    the two from disagreeing. -}
wiredInArity :: Text -> Maybe Int
wiredInArity name = case name of
  "Option" -> Just 1
  "Result" -> Just 2
  "Array" -> Just 1
  "Task" -> Just 2
  _ | name `elem` scalarNames -> Just 0
  _ -> Nothing

scalarNames :: [Text]
scalarNames =
  [ "Int8", "Int16", "Int32", "Int64", "Int128", "Int"
  , "UInt8", "UInt16", "UInt32", "UInt64", "UInt128", "UInt"
  , "Float32", "Float64", "Float", "Bool", "Char", "Str", "Never", "BigInt"
  ]

arrowKind :: Int -> Text
arrowKind arity
  | arity <= 0 = "type"
  | otherwise = Text.intercalate " -> " (replicate (arity + 1) "type")

renderSignature :: Function -> Text
renderSignature value =
  exportPrefix (functionVisibility value)
    <> comptimePrefix (functionComptime value)
    <> unsafePrefix (functionUnsafe value)
    <> asyncPrefix (functionAsync value)
    <> "fn " <> locatedValue (functionName value)
    <> renderTypeParams (functionTypeParams value)
    <> "(" <> Text.intercalate ", " (map (renderParameter . locatedValue) (functionParameters value)) <> ")"
    <> maybe Text.empty (\syntax -> " -> " <> renderType syntax) (functionReturn value)

renderParameter :: Parameter -> Text
renderParameter parameter =
  locatedValue (parameterName parameter)
    <> maybe Text.empty (\syntax -> ": " <> renderType syntax) (parameterType parameter)

renderTypeDeclaration :: TypeDeclarationValue -> Text
renderTypeDeclaration value =
  exportPrefix (typeVisibility value)
    <> "type " <> locatedValue (typeName value)
    <> renderTypeParams (typeTypeParams value)
    <> " = " <> renderDefinition (locatedValue (typeDefinition value))

renderDefinition :: TypeDefinition -> Text
renderDefinition definition = case definition of
  RecordDefinition fields ->
    "{ " <> Text.intercalate ", " (map (renderField . locatedValue) fields) <> " }"
  SumDefinition variants ->
    Text.intercalate " | " (map (renderVariant . locatedValue) variants)
  AliasDefinition aliased -> renderType aliased
  InvalidDefinition -> "?"

renderField :: FieldDeclaration -> Text
renderField field =
  (if fieldMutable field then "mut " else Text.empty)
    <> locatedValue (fieldName field) <> ": " <> renderType (fieldType field)

renderVariant :: Variant -> Text
renderVariant variant =
  locatedValue (variantName variant) <> case variantPayload variant of
    UnitPayload -> Text.empty
    TuplePayload members -> "(" <> Text.intercalate ", " (map renderType members) <> ")"
    RecordPayload fields ->
      "{ " <> Text.intercalate ", " (map (renderField . locatedValue) fields) <> " }"

renderMacro :: Macro -> Text
renderMacro value =
  exportPrefix (macroVisibility value)
    <> "macro " <> locatedValue (macroName value)
    <> "(" <> Text.intercalate ", " (map (renderMacroParam . locatedValue) (macroParameters value)) <> ")"

renderMacroParam :: MacroParam -> Text
renderMacroParam parameter =
  locatedValue (macroParamName parameter) <> ": " <> case macroParamKind parameter of
    ExpressionKind -> "expr"
    IdentifierKind -> "ident"
    BlockKind -> "block"

renderTypeParams :: [Located TypeParam] -> Text
renderTypeParams params
  | null params = Text.empty
  | otherwise = "[" <> Text.intercalate ", " (map (renderTypeParam . locatedValue) params) <> "]"

renderTypeParam :: TypeParam -> Text
renderTypeParam param =
  locatedValue (typeParamName param) <> case typeParamBounds param of
    [] -> Text.empty
    bounds -> ": " <> Text.intercalate " + " (map renderType bounds)

renderType :: Located TypeSyntax -> Text
renderType (Located _ syntax) = case syntax of
  DynamicType path -> "dynamic " <> moduleNameText path
  NamedType path arguments ->
    moduleNameText path
      <> if null arguments
           then Text.empty
           else "[" <> Text.intercalate ", " (map renderType arguments) <> "]"
  ReferenceType mutable target ->
    (if mutable then "&mut " else "&") <> renderType target
  TupleType members -> "(" <> Text.intercalate ", " (map renderType members) <> ")"
  FunctionType asynchronous inputs result ->
    (if asynchronous then "async fn(" else "fn(")
      <> Text.intercalate ", " (map renderType inputs) <> ") -> " <> renderType result
  UnitType -> "()"
  InvalidType -> "?"

targetName :: Located TypeSyntax -> Maybe Text
targetName (Located _ syntax) = case syntax of
  NamedType (ModuleName segments) _ -> Just (NonEmpty.last segments)
  _ -> Nothing

exportPrefix :: Visibility -> Text
exportPrefix visibility = if visibility == Exported then "export " else Text.empty

asyncPrefix :: Bool -> Text
asyncPrefix asynchronous = if asynchronous then "async " else Text.empty

comptimePrefix :: Bool -> Text
comptimePrefix comptime = if comptime then "comptime " else Text.empty

unsafePrefix :: Maybe [Located Capability] -> Text
unsafePrefix unsafety = case unsafety of
  Nothing -> Text.empty
  Just [] -> "unsafe "
  Just capabilities ->
    "unsafe(" <> Text.intercalate ", " (map (capabilityName . locatedValue) capabilities) <> ") "

capabilityName :: Capability -> Text
capabilityName capability = case capability of
  RawCapability -> "raw"
  ForeignCapability -> "foreign"
  UncheckedCapability -> "unchecked"
  NullCapability -> "null"

{-| `:kind` as the prompt prints it: the answer, or a note that the session has
    never heard the name. -}
describeKindLines :: Module -> Text -> [Text]
describeKindLines moduleValue name = case describeKind moduleValue name of
  Just rendered -> [rendered]
  Nothing -> ["not in scope: type '" <> name <> "'"]

{-| One line per declaration, in source order — the session's table of
    contents rather than its contents. -}
declarationSummary :: Module -> [Text]
declarationSummary moduleValue =
  map (summarise . locatedValue) (filter (not . synthetic) (moduleDeclarations moduleValue))
 where
  synthetic entry = case locatedValue entry of
    FunctionDeclaration value -> "__" `Text.isPrefixOf` locatedValue (functionName value)
    _ -> False

  summarise declaration = case declaration of
    BindingDeclaration _ kind name _ _ -> bindingWord kind <> " " <> locatedValue name
    FunctionDeclaration value -> "fn " <> locatedValue (functionName value)
    TypeDeclaration value -> "type " <> locatedValue (typeName value)
    TraitDeclaration value -> "trait " <> locatedValue (traitName value)
    ImplDeclaration value ->
      "impl " <> renderType (implTrait value) <> " for " <> renderType (implTarget value)
    MacroDeclaration value -> "macro " <> locatedValue (macroName value)
    InvalidDeclaration -> "<invalid declaration>"

  bindingWord kind = case kind of
    Immutable -> "let"
    Mutable -> "let mut"
    CompileTime -> "const"

{-| Every module the session has pulled in, in the order it asked for them. -}
importSummary :: Module -> [Text]
importSummary moduleValue =
  [ moduleNameText (locatedValue (importModule (locatedValue entry)))
  | entry <- moduleImports moduleValue
  ]
