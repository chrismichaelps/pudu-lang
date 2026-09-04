{-| @Doc.Module — builds a searchable index of what a module declares -}
module Pudu.Doc
  ( DocEntry (..)
  , DocIndex (..)
  , DocKind (..)
  , buildIndex
  , entriesFor
  , kindLabel
  , renderEntry
  , renderEntryLines
  , renderEntryLinesWith
  ) where

import qualified Data.List as List
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Doc.Signature (SigType (..), Signature (..), renderSignature, schemeSignature)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Foreign (..)
  , ForeignFunction (..)
  , Function (..)
  , Impl (..)
  , Macro (..)
  , Module (..)
  , Trait (..)
  , TypeDeclarationValue (..)
  , TypeSyntax (..)
  )
import Pudu.Frontend.Token (Token (..), Trivia (..), TriviaKind (DocComment, Whitespace))
import Pudu.Source (spanEnd, spanStart, unOffset)
import Pudu.Type (ModuleTypes (..), Scheme)

{-| @Doc.Kind — what a documented name is.

    The kind is what a reader filters on and what an editor draws an icon for,
    so it names the declaration form rather than the internal representation. -}
data DocKind
  = DocFunction
  | DocTraitMethod !Text
  | DocMethod !Text
  | DocConstant
  | DocType
  | DocTrait
  | DocMacro
  {-| A function of a library written elsewhere, and the library it is in.

      Kept apart from an ordinary function because the difference matters to
      whoever is reading: its type was asserted by whoever wrote the
      declaration and proved by nothing, and a reader deciding how carefully to
      check a call wants to be told that without having to go and look. -}
  | DocForeign !Text
  deriving stock (Eq, Ord, Show)

{-| @Doc.Entry — one documented name.

    `docSignature` comes from the checker, never from the written annotation, so
    an unannotated declaration is still searchable and an annotated one is
    described as the compiler understood it. `docSpan` is what an editor jumps
    to, and `docComment` is what it shows on hover. -}
data DocEntry = DocEntry
  { docName :: !Text
  , docKind :: !DocKind
  , docModule :: !Text
  , docSignature :: !(Maybe Signature)
  , docComment :: ![Text]
  , docSpan :: !(Int, Int)
  }
  deriving stock (Eq, Show)

{-| @Doc.Index — every documented name in one module, in declaration order. -}
newtype DocIndex = DocIndex {indexEntries :: [DocEntry]}
  deriving stock (Eq, Show)

instance Semigroup DocIndex where
  DocIndex left <> DocIndex right = DocIndex (left <> right)

instance Monoid DocIndex where
  mempty = DocIndex []

{-| Build the index for one checked module.

    Three sources meet here and each answers only what it is authoritative for:
    the module says what was declared and where, the checker says what type each
    declaration has, and the token stream says what was documented. Nothing is
    re-derived from a source that only approximates it — in particular the
    signature is never reconstructed from the written syntax, because the
    written syntax is optional and the inferred type is not. -}
buildIndex :: [Token] -> ModuleTypes -> Module -> DocIndex
buildIndex tokens types moduleValue =
  DocIndex (concat (snd (List.mapAccumL step moduleStart (moduleDeclarations moduleValue))))
 where
  moduleStart = unOffset (spanStart (moduleSpan moduleValue))

  {-| Declarations are walked in source order so each one knows where the
      previous one ended. That bound is what makes "the documentation just above
      this declaration" a precise notion rather than a guess. -}
  step previousEnd located@(Located declarationSpan _) =
    ( unOffset (spanEnd declarationSpan)
    , entry previousEnd located
    )

  owner = moduleNameText (locatedValue (moduleName moduleValue))
  schemes = Map.fromList (moduleSchemes types)
  docs = docComments tokens

  entry lowerBound (Located declarationSpan declaration) = case declaration of
    BindingDeclaration _ _ name _ _ ->
      [make lowerBound (locatedValue name) DocConstant declarationSpan (locatedValue name)]
    FunctionDeclaration value ->
      [ make
          lowerBound
          (locatedValue (functionName value))
          DocFunction
          declarationSpan
          (locatedValue (functionName value))
      ]
    TypeDeclaration value ->
      [make lowerBound (locatedValue (typeName value)) DocType declarationSpan (locatedValue (typeName value))]
    TraitDeclaration value ->
      make lowerBound (locatedValue (traitName value)) DocTrait declarationSpan (locatedValue (traitName value))
        : memberEntries (traitMember (locatedValue (traitName value))) declarationSpan (traitMembers value)
    ImplDeclaration value -> memberEntries (implMember value) declarationSpan (implFunctions value)
    MacroDeclaration value ->
      [make lowerBound (locatedValue (macroName value)) DocMacro declarationSpan (locatedValue (macroName value))]
    {-| A foreign declaration is the only description of those functions that
        exists, so each one carries its own entry: there is no body to read
        instead and nowhere else the documentation could live. -}
    ForeignDeclaration value ->
      snd
        ( List.mapAccumL
            foreignEntry
            (unOffset (spanStart declarationSpan))
            (List.sortOn foreignMemberStart foreignMembers)
        )
     where
      foreignMembers =
        map Left (foreignTypes value) <> map Right (foreignFunctions value)
      foreignMemberStart member = case member of
        Left (Located memberSpan _) -> unOffset (spanStart memberSpan)
        Right (Located memberSpan _) -> unOffset (spanStart memberSpan)
      foreignEntry previousEnd member = case member of
        Left (Located typeSpan name) ->
          ( unOffset (spanEnd typeSpan)
          , make previousEnd name DocType typeSpan name
          )
        Right (Located functionSpan function) ->
          let name = locatedValue (foreignName function)
           in ( unOffset (spanEnd functionSpan)
              , make previousEnd name
                  (DocForeign (locatedValue (foreignLibrary value)))
                  functionSpan name
              )
    InvalidDeclaration -> []

  {-| A member's documentation is bounded by its enclosing declaration rather
      than by the previous top-level one, so the first member cannot claim the
      trait's own documentation. -}
  memberEntries render holderSpan members =
    snd (List.mapAccumL memberStep (unOffset (spanStart holderSpan)) members)
   where
    memberStep previousEnd located@(Located memberSpan _) =
      (unOffset (spanEnd memberSpan), render previousEnd located)

  traitMember holder lowerBound (Located memberSpan value) =
    make
      lowerBound
      (locatedValue (functionName value))
      (DocTraitMethod holder)
      memberSpan
      (holder <> "." <> locatedValue (functionName value))

  implMember holder lowerBound (Located memberSpan value) =
    make
      lowerBound
      (locatedValue (functionName value))
      (DocMethod (implLabel holder))
      memberSpan
      (implLabel holder <> "." <> locatedValue (functionName value))

  make lowerBound name kind spanValue key =
    DocEntry
      { docName = name
      , docKind = kind
      , docModule = owner
      , docSignature = concreteSelf kind . schemeSignature <$> lookupScheme key name
      , docComment = docsBefore lowerBound (unOffset (spanStart spanValue))
      , docSpan = (unOffset (spanStart spanValue), unOffset (spanEnd spanValue))
      }

  {-| The documentation immediately above a declaration.

      A declaration's span starts at its `fn` or `type` keyword, not at the
      `export` in front of it, so the doc comment leads a token the span does
      not contain. Looking backwards for the nearest documented token — but no
      further back than the previous declaration ended — attaches it correctly
      whatever modifiers were written, and cannot reach past a declaration into
      another one's documentation. -}
  docsBefore lowerBound start =
    case Map.lookupLE start docs of
      Just (offset, found) | offset >= lowerBound -> found
      _ -> []

  {-| Find the scheme the checker recorded for this declaration.

      A member is keyed by the nominal type it belongs to, and that type may be
      qualified by the module that declared it — so a trait's own member is
      under `Owner.Trait.method` while a method on a builtin is under
      `Int.method`. Trying the candidates in order of specificity finds the
      right one without the index having to reimplement the checker's naming.

      The plain name is the last candidate rather than the first: a module with
      both a free `label` and a `Label.label` must not describe one as the
      other. -}
  lookupScheme :: Text -> Text -> Maybe Scheme
  lookupScheme key name =
    case mapMaybe (`Map.lookup` schemes) candidates of
      found : _ -> Just found
      [] -> Nothing
   where
    candidates
      | key == name = [name]
      | otherwise = [owner <> "." <> key, key, name]

{-| Report an implementation's methods against the type they are implemented
    for rather than against `Self`.

    The checker keeps `Self` rigid inside an implementation because that is what
    lets one method call another, but a reader looking up `Int.before` is asking
    about `Int`, and answering with `Self` would make them resolve the binding
    themselves. A trait's own member keeps `Self`: there it is the point. -}
concreteSelf :: DocKind -> Signature -> Signature
concreteSelf kind signature = case kind of
  DocMethod holder ->
    signature
      { signatureArguments = map (substitute holder) (signatureArguments signature)
      , signatureResult = substitute holder (signatureResult signature)
      }
  _ -> signature
 where
  substitute holder sigType = case sigType of
    SigVar "Self" -> SigCon holder []
    SigCon "Self" [] -> SigCon holder []
    SigCon name arguments -> SigCon name (map (substitute holder) arguments)
    SigRef mutable target -> SigRef mutable (substitute holder target)
    SigTuple members -> SigTuple (map (substitute holder) members)
    SigFun inputs result -> SigFun (map (substitute holder) inputs) (substitute holder result)
    other -> other

{-| The head of an implementation, used to qualify the methods it provides.

    Only the head name is needed: the checker keys a method by the nominal type
    it is implemented for, and the arguments of that type do not distinguish two
    implementations that would already have been rejected as overlapping. -}
implLabel :: Impl -> Text
implLabel value = case locatedValue (implTarget value) of
  NamedType path _ -> moduleNameText path
  ReferenceType _ inner -> case locatedValue inner of
    NamedType path _ -> moduleNameText path
    _ -> "?"
  _ -> "?"

{-| Doc comments keyed by the offset of the token they lead.

    A declaration's documentation is the run of `///` lines (or one `/** */`
    block) immediately before it, with nothing but whitespace between. A comment
    separated from the declaration by another comment is not documentation for
    it: the reader who wrote a note between the two meant the note, not the
    attachment. -}
docComments :: [Token] -> Map Int [Text]
docComments tokens =
  Map.fromList (mapMaybe attached tokens)
 where
  attached token = case leading token of
    [] -> Nothing
    found -> Just (unOffset (spanStart (tokenSpan token)), found)

  leading = concatMap body . takeTrailingRun . tokenLeadingTrivia

  takeTrailingRun = reverse . takeWhile isDoc . reverse . filter (not . isBlank)

  isBlank trivia = triviaKind trivia == Whitespace
  isDoc trivia = triviaKind trivia == DocComment

  body = docLines . triviaText

{-| Strip a doc comment's markers and its common indentation, so what a reader
    wrote is what a reader sees. -}
docLines :: Text -> [Text]
docLines raw
  | Text.isPrefixOf "///" raw = [Text.strip (Text.drop 3 raw)]
  | Text.isPrefixOf "/**" raw =
      map cleanBlockLine (Text.lines (Text.dropEnd 2 (Text.drop 3 raw)))
  | otherwise = [Text.strip raw]
 where
  cleanBlockLine = Text.strip . Text.dropWhile (== '*') . Text.stripStart

{-| Every entry for a name, in declaration order. A name can appear more than
    once — a method on two implementations, for instance — and reporting only
    the first would hide the ambiguity a reader is asking about. -}
entriesFor :: Text -> DocIndex -> [DocEntry]
entriesFor name = filter ((== name) . docName) . indexEntries

kindLabel :: DocKind -> Text
kindLabel kind = case kind of
  DocFunction -> "fn"
  DocTraitMethod holder -> "fn (trait " <> holder <> ")"
  DocMethod holder -> "fn (" <> holder <> ")"
  DocConstant -> "const"
  DocType -> "type"
  DocTrait -> "trait"
  DocMacro -> "macro"
  DocForeign _ -> "foreign"

{-| One line, the way a search result lists it: the name, its type, and where it
    came from. -}
renderEntry :: DocEntry -> Text
renderEntry value =
  docName value
    <> maybe Text.empty (\signature -> " :: " <> renderSignature signature) (docSignature value)

{-| The full description, the way a documentation listing shows it. -}
renderEntryLines :: DocEntry -> [Text]
renderEntryLines = renderEntryLinesWith True

{-| The same description, with the owning module named only when it tells the
    reader something.

    At the prompt it does not: every answer comes from the session the reader is
    sitting in, and printing its synthetic module name would be noise dressed as
    provenance. -}
renderEntryLinesWith :: Bool -> DocEntry -> [Text]
renderEntryLinesWith withProvenance value =
  (renderEntry value : provenance) <> docComment value
 where
  provenance
    | withProvenance = [kindLabel (docKind value) <> " · " <> docModule value]
    | otherwise = [kindLabel (docKind value)]
