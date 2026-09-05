{-| @Program.Eval.Install — puts a module's declarations into the environment -}
module Pudu.Eval.Install
  ( Evaluate
  , loadDeclarations
  , lastSegmentOf
  , targetNameOf
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Foreign.Crossing (Crossing (NothingCrossing), RecordLayouts, crossingFor, recordLayouts)
import Pudu.Eval.Builtin
  ( effectBuiltins
  )
import Pudu.Eval.Env
  ( Evaluator (..)
  , bind
  , recordVariantOwner
  , bindMethod
  )
import Pudu.Eval.Value
  ( Builtin (..)
  , builtinName
  , Closure (..)
  , ForeignBinding (..)
  , ForeignRelease (..)
  , ForeignSlot (..)
  , Value (..)
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Expression (..)
  , Foreign (..)
  , ForeignFunction (..)
  , ForeignParameter (..)
  , Function (..)
  , Impl (..)
  , Trait (..)
  , TypeDeclarationValue (..)
  , TypeSyntax (..)
  , TypeDefinition (..)
  , Variant (..)
  )

{-| @Eval.Install.Evaluate — evaluating an expression.

    A module constant's value is an expression, and evaluating one needs the
    environment this module installs. One direction has to be an argument
    rather than an import, and this is that direction. -}
type Evaluate = Located Expression -> Evaluator Value

{-| Functions and variant constructors are installed before any constant runs,
    so mutual recursion and forward references work exactly as resolution
    promised they would. -}
loadDeclarations :: Evaluate -> [Located Declaration] -> Evaluator ()
loadDeclarations evaluateWith declarations = do
  installBuiltinConstructors
  let traits = traitTable declarations
      layouts = recordLayouts declarations
  mapM_ (installDeclaration traits layouts) declarations
  mapM_ (initializeDeclaration evaluateWith) declarations

{-| Trait members by trait name, so an implementation inherits the defaults it
    does not override. -}
traitTable :: [Located Declaration] -> Map Text [Located Function]
traitTable declarations =
  Map.fromList
    [ (locatedValue (traitName value), traitMembers value)
    | Located _ (TraitDeclaration value) <- declarations
    ]

{-| The wired-in sums' constructors and the prelude's builtin functions exist
    without a declaration. A module that declares its own is installed
    afterwards and therefore wins. -}
installBuiltinConstructors :: Evaluator ()
installBuiltinConstructors = do
  mapM_ (\name -> bind name (VariantValue name []))
    ["Some", "None", "Ok", "Err"]
  {-| The wired-in sums own their variants the way a declared sum does. Without
      this an implementation written for `Option` is looked for under `Some`,
      and the reader is told a type they never wrote has no such member. -}
  mapM_ (uncurry recordVariantOwner)
    [("Some", "Option"), ("None", "Option"), ("Ok", "Result"), ("Err", "Result")]
  bind "panic" (BuiltinValue PanicBuiltin)
  bind "charFromCode" (BuiltinValue CharFromCodeBuiltin)
  bind "mapOf" (BuiltinValue MapOfBuiltin)
  bind "setOf" (BuiltinValue SetOfBuiltin)
  bind "bytesOf" (BuiltinValue BytesOfBuiltin)
  bind "bucketsOf" (BuiltinValue BucketsOfBuiltin)
  bind "sha256Of" (BuiltinValue Sha256Builtin)
  bind "hmacSha256Of" (BuiltinValue HmacBuiltin)
  bind "deriveKey" (BuiltinValue DeriveKeyBuiltin)
  bind "hashOf" (BuiltinValue HashOfBuiltin)
  bind "mixHash" (BuiltinValue MixHashBuiltin)
  bind "show" (BuiltinValue ShowBuiltin)
  bind "display" (BuiltinValue DisplayBuiltin)
  bind "convertInteger" (BuiltinValue ConvertIntegerBuiltin)
  bind "decimalOf" (BuiltinValue DecimalOfBuiltin)
  bind "decimalFromInt" (BuiltinValue DecimalFromIntBuiltin)
  bind "decimalScale" (BuiltinValue DecimalScaleBuiltin)
  bind "decimalToInt" (BuiltinValue DecimalToIntBuiltin)
  bind "decimalToFloat" (BuiltinValue DecimalToFloatBuiltin)
  bind "decimalDivide" (BuiltinValue DecimalDivideBuiltin)
  bind "decimalRound" (BuiltinValue DecimalRoundBuiltin)
  mapM_ (\builtin -> bind (builtinName builtin) (BuiltinValue builtin)) effectBuiltins

installDeclaration
  :: Map Text [Located Function] -> RecordLayouts -> Located Declaration -> Evaluator ()
installDeclaration traits layouts (Located _ declaration) = case declaration of
  FunctionDeclaration value ->
    bind (locatedValue (functionName value))
      (FunctionValue (Closure (locatedValue (functionName value)) value Nothing Nothing))
  TypeDeclaration value ->
    installVariants (locatedValue (typeName value)) (typeDefinition value)
  ImplDeclaration value -> installMethods traits value
  ForeignDeclaration value -> mapM_ (installForeign layouts value) (foreignFunctions value)
  _ -> pure ()

{-| One foreign function becomes a value under its own name.

    Everything the call needs is settled here rather than looked up when it
    runs: the library, the symbol, and how each value crosses. A call is then a
    call, and a declaration that could not be resolved into one has already been
    reported by the checker. -}
installForeign :: RecordLayouts -> Foreign -> Located ForeignFunction -> Evaluator ()
installForeign layouts library (Located _ function) =
  bind name
    ( ForeignValue
        ForeignBinding
          { foreignBindingLibrary = locatedValue (foreignLibrary library)
          , foreignBindingBorrowedResult = foreignResultBorrowed function
          , foreignBindingVersion = locatedValue <$> foreignVersion library
          , foreignBindingSymbol = maybe name locatedValue (foreignSymbol function)
          , foreignBindingArguments =
              [ crossingOf parameter
              | Located _ parameter <- foreignParameters function
              ]
          , foreignBindingSlots =
              [ if foreignParameterOut parameter
                  then
                    Just
                      ForeignSlot
                        { foreignSlotCrossing = crossingOf parameter
                        , foreignSlotReleasedBy = do
                            named <- locatedValue <$> foreignParameterReleasedBy parameter
                            symbol <- Map.lookup named (releaseSymbolsOf library)
                            pure
                              ForeignRelease
                                { foreignReleaseLibrary = locatedValue (foreignLibrary library)
                                , foreignReleaseVersion = locatedValue <$> foreignVersion library
                                , foreignReleaseSymbol = symbol
                                }
                        }
                  else Nothing
              | Located _ parameter <- foreignParameters function
              ]
          , foreignBindingResult =
              fromMaybe NothingCrossing (crossingFor handles layouts (foreignResult function))
          , foreignBindingReleasedBy = do
              named <- locatedValue <$> foreignReleasedBy function
              symbol <- Map.lookup named (releaseSymbolsOf library)
              pure
                ForeignRelease
                  { foreignReleaseLibrary = locatedValue (foreignLibrary library)
                  , foreignReleaseVersion = locatedValue <$> foreignVersion library
                  , foreignReleaseSymbol = symbol
                  }
          , foreignBindingReleases = Map.lookup name (releasesOf library)
          }
    )
 where
  name = locatedValue (foreignName function)
  handles = Set.fromList (map locatedValue (foreignTypes library))
  crossingOf parameter =
    fromMaybe NothingCrossing (foreignParameterType parameter >>= crossingFor handles layouts)

{-| The functions of a block that release something.

    Read from the declarations rather than from a name, so a release is
    whatever some function in the same block named after `by` — which is the
    only place that fact is written. -}
releasesOf :: Foreign -> Map Text Text
releasesOf library =
  Map.fromList (concatMap named (foreignFunctions library))
 where
  {-| A release is named by whatever it frees, and a resource arrives either as
      the result or through a slot. Reading only the result left a slot's
      release unrecognised: the program's explicit call went straight to the
      library while the claim stayed in the store, and teardown freed what the
      library had already destroyed. -}
  named (Located _ function) =
    [ (locatedValue name, handle)
    | (Just name, written) <- releasing function
    , let handle = handleName (locatedValue written)
    , isHandleName handle
    ]
  {-| Each place this function may name a release, beside what that release
      would free. -}
  releasing function =
    (foreignReleasedBy function, foreignResult function)
      : [ (foreignParameterReleasedBy parameter, held)
        | Located _ parameter <- foreignParameters function
        , foreignParameterOut parameter
        , Just held <- [foreignParameterType parameter]
        ]
  known = Set.fromList (map locatedValue (foreignTypes library))
  isHandleName = (`Set.member` known)
  handleName syntax = case syntax of
    NamedType (ModuleName (name :| [])) [] -> name
    _ -> ""

{-| Local release name to exact loader symbol. The `by` clause is local Pudu
    syntax, while teardown must invoke the same mapped symbol as an explicit
    call to that release declaration. -}
releaseSymbolsOf :: Foreign -> Map Text Text
releaseSymbolsOf library =
  Map.fromList
    [ (name, maybe name locatedValue (foreignSymbol function))
    | Located _ function <- foreignFunctions library
    , let name = locatedValue (foreignName function)
    ]

{-| An implementation's functions are installed under a key naming the type they
    implement for, so a member access on a value of that type finds them. -}
installMethods :: Map Text [Located Function] -> Impl -> Evaluator ()
installMethods traits value = case targetNameOf (implTarget value) of
  Nothing -> pure ()
  Just owner -> do
    mapM_ (installMethod owner) (implFunctions value)
    mapM_ (installMethod owner) (inheritedDefaults traits value)
 where
  installMethod owner (Located _ method) = do
    let name = locatedValue (functionName method)
        implementation = FunctionValue (Closure name method Nothing Nothing)
    bindMethod (owner <> "." <> name) implementation
    case traitNameOf (implTrait value) of
      Nothing -> pure ()
      Just traitText -> bindMethod (traitText <> "." <> owner <> "." <> name) implementation

{-| A trait member with a body is a default the implementation inherits when it
    does not provide its own. -}
inheritedDefaults :: Map Text [Located Function] -> Impl -> [Located Function]
inheritedDefaults traits value = case traitNameOf (implTrait value) of
  Nothing -> []
  Just traitText ->
    [ member
    | member@(Located _ method) <- maybe [] id (Map.lookup traitText traits)
    , functionBody method /= Nothing
    , locatedValue (functionName method) `notElem` provided
    ]
 where
  provided = map (locatedValue . functionName . locatedValue) (implFunctions value)

traitNameOf :: Located TypeSyntax -> Maybe Text
traitNameOf = targetNameOf

targetNameOf :: Located TypeSyntax -> Maybe Text
targetNameOf (Located _ syntax) = case syntax of
  NamedType (ModuleName segments) _ -> Just (lastSegmentOf segments)
  _ -> Nothing

{-| Each variant is bound unqualified and, together with its siblings, under its
    type's name. A variant with a payload starts life as an empty constructor
    that a call fills in, so `Circle` and `Shape.Circle(3)` reach the same
    value. -}
installVariants :: Text -> Located TypeDefinition -> Evaluator ()
installVariants typeText (Located _ definition) = case definition of
  SumDefinition variants -> do
    let entries = map variantEntry variants
    mapM_ (uncurry bind) entries
    mapM_ (\(name, _) -> recordVariantOwner name typeText) entries
    bind typeText (RecordValue typeText entries)
  _ -> pure ()
 where
  variantEntry (Located _ variant) =
    let name = locatedValue (variantName variant)
     in (name, VariantValue name [])

initializeDeclaration :: Evaluate -> Located Declaration -> Evaluator ()
initializeDeclaration evaluateWith (Located _ declaration) = case declaration of
  BindingDeclaration _ _ name _ value -> do
    evaluated <- evaluateWith value
    bind (locatedValue name) evaluated
  _ -> pure ()

lastSegmentOf :: NonEmpty Text -> Text
lastSegmentOf (first :| rest) = last (first : rest)
