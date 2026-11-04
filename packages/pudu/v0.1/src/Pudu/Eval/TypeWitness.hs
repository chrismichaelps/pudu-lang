{-| @Eval.TypeWitness — lexical type witnesses and structural implementation parameter binding. -}
module Pudu.Eval.TypeWitness
  ( witnessOf, selectTypes, withSelf, selectImplementation, witnessMethod ) where

import Control.Monad (foldM)
import Data.List (nub, sort)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Eval.Env (Evaluator, abortAt, lookupLocal, lookupName, lookupMethod)
import Pudu.Eval.ImplementationHead (HeadSelection (..), ImplementationHead (..))
import Pudu.Eval.Value (Closure (..), Value (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameText)
import qualified Data.List.NonEmpty as NonEmpty
import Pudu.Frontend.Syntax.Tree (Function (..), TypeParam (..), TypeSyntax (..))
import Pudu.Source (Span)

{-| Lexical constructor witnesses keep their canonical head when applied. -}
witnessOf :: Located TypeSyntax -> Evaluator Value
witnessOf (Located _ written) = case written of
  NamedType path@(ModuleName (first NonEmpty.:| rest)) arguments -> do
    local <- if null rest then lookupLocal first else pure Nothing
    case local of
      Just witness@TypeWitnessValue{} | null arguments -> pure witness
      Just (TypeWitnessValue owner held) -> TypeWitnessValue owner . (held <>) <$> mapM witnessOf arguments
      _ -> TypeWitnessValue (moduleNameText path) <$> mapM witnessOf arguments
  _ -> case witnessShape written of
    Just (owner, arguments) -> TypeWitnessValue owner <$> mapM witnessOf arguments
    Nothing -> pure (TypeWitnessValue Text.empty [])

withSelf :: Value -> Closure -> Closure
withSelf witness closure = closure{closureWitnesses = ("Self", witness) : closureWitnesses closure}

{-| An already matched implementation leaves only method-local explicit parameters. -}
selectTypes :: [Value] -> Closure -> Closure
selectTypes [] closure = closure
selectTypes chosen closure = closure
  { closureWitnesses = zip parameters chosen <> closureWitnesses closure }
 where
  written = map (locatedValue . typeParamName . locatedValue) (functionTypeParams (closureFunction closure))
  parameters = case closureImplementation closure of
    Just ImplementationHead{headSelection = SelectedHead, headParameters} -> drop (length headParameters) written
    _ -> written

{-| Match checked structure without reading erased type arguments from program data. -}
selectImplementation :: Span -> Value -> Closure -> Evaluator Closure
selectImplementation at witness closure = case closureImplementation closure of
  Nothing -> pure (withSelf witness (selectTypes (argumentsOf witness) closure))
  Just metadata@ImplementationHead{headParameters, headTarget} ->
    case match headParameters headTarget witness Map.empty of
      Nothing -> abortAt (Just at) "E7001" "selected type does not match its implementation target" Nothing
      Just bindings -> pure $ withSelf witness closure
        { closureImplementation = Just metadata{headSelection = SelectedHead}
        , closureWitnesses = Map.toList bindings <> closureWitnesses closure
        }
 where
  argumentsOf (TypeWitnessValue _ arguments) = arguments
  argumentsOf _ = []

match :: [Text] -> Located TypeSyntax -> Value -> Map.Map Text Value -> Maybe (Map.Map Text Value)
match parameters (Located _ written) actual bindings = case written of
  NamedType (ModuleName (name NonEmpty.:| [])) arguments | name `elem` parameters ->
    if null arguments then bind name actual bindings else case actual of
      TypeWitnessValue owner given -> do
        chosen <- bind name (TypeWitnessValue owner []) bindings
        matchArguments parameters arguments given chosen
      _ -> Nothing
  _ -> case (witnessShape written, actual) of
    (Just (owner, arguments), TypeWitnessValue selected given) | owner == selected ->
      matchArguments parameters arguments given bindings
    _ -> Nothing

matchArguments :: [Text] -> [Located TypeSyntax] -> [Value] -> Map.Map Text Value -> Maybe (Map.Map Text Value)
matchArguments parameters written given bindings
  | length written /= length given = Nothing
  | otherwise = foldM (\current (target, actual) -> match parameters target actual current) bindings (zip written given)

bind :: Text -> Value -> Map.Map Text Value -> Maybe (Map.Map Text Value)
bind name actual bindings = case Map.lookup name bindings of
  Nothing -> Just (Map.insert name actual bindings)
  Just previous | previous == actual -> Just bindings
  _ -> Nothing

{-| Private structural tags cannot collide with a checked nominal declaration. -}
witnessShape :: TypeSyntax -> Maybe (Text, [Located TypeSyntax])
witnessShape written = case written of
  NamedType path arguments -> Just (moduleNameText path, arguments)
  TupleType members -> Just ("::tuple::", members)
  ReferenceType mutable target -> Just (if mutable then "::ref-mut::" else "::ref::", [target])
  FunctionType asynchronous inputs result -> Just (if asynchronous then "::async-fn::" else "::fn::", inputs <> [result])
  DynamicType path -> Just ("::dynamic:" <> moduleNameText path <> "::", [])
  UnsafeType capabilities target ->
    Just ("::unsafe:" <> Text.pack (show (nub (sort (map (fromEnum . locatedValue) capabilities)))) <> "::", [target])
  UnitType -> Just ("::unit::", [])
  InvalidType -> Nothing

{-| Qualification and retained member reads share one witnessed selection. -}
witnessMethod :: Span -> Value -> Text -> Evaluator (Maybe Value)
witnessMethod at witness member = case witness of
  TypeWitnessValue owner _ -> do
    found <- (if Text.isPrefixOf "::" member then lookupMethod else lookupName) (owner <> "." <> member)
    case found of
      Just (FunctionValue closure) -> Just . FunctionValue <$> selectImplementation at witness closure
      other -> pure other
  _ -> pure Nothing
