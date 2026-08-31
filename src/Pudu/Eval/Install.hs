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
import Data.Text (Text)
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
  , Value (..)
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Expression (..)
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
  mapM_ (installDeclaration traits) declarations
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

installDeclaration :: Map Text [Located Function] -> Located Declaration -> Evaluator ()
installDeclaration traits (Located _ declaration) = case declaration of
  FunctionDeclaration value ->
    bind (locatedValue (functionName value))
      (FunctionValue (Closure (locatedValue (functionName value)) value Nothing Nothing))
  TypeDeclaration value ->
    installVariants (locatedValue (typeName value)) (typeDefinition value)
  ImplDeclaration value -> installMethods traits value
  _ -> pure ()

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
