{-| @Test.Backend.LowerTypesSpec — canonical solved native fact boundaries. -}
module Pudu.Backend.LowerTypesSpec (lowerTypesProperties) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Compiler.Lower (LowerResult (..), lowerProgram)
import Pudu.Compiler.Lower.Types (formedCoreType, nativeTypes, typeForSpan)
import Pudu.Core (CoreType (..))
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText, diagnosticSpan, hasErrors)
import Pudu.Frontend.Syntax (Module (..), ModuleName (..))
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned))
import Pudu.Source (SourceName (..), emptySpan, generatedSpan, newSource)
import Pudu.Type (TypeInfo (..))
import Pudu.Type.Value (NominalId (..), Type (..), boolType, integerType, stringType)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

lowerTypesProperties :: [(String, IO Property)]
lowerTypesProperties =
  [ ("native representation uses canonical solved identities", pure testCanonical)
  , ("native type facts retain source and generated span identities", testSpans)
  , ("native lowering refuses missing analysis facts", testMissing)
  ]

testCanonical :: Property
testCanonical = conjoin
  [ formedCoreType integerType === Just (CoreIntegerType PlatformSigned)
  , formedCoreType boolType === Just CoreBoolType
  , formedCoreType stringType === Just CoreTextType
  , formedCoreType UnitTypeValue === Just CoreUnitType
  , formedCoreType NeverType === Just CoreNeverType
  , formedCoreType (NominalType (NominalId (Just (ModuleName ("User" :| []))) "Int") []) === Nothing
  , formedCoreType (TupleTypeValue []) === Nothing
  , formedCoreType (NominalType "Int8" []) === Nothing
  ]

testSpans :: IO Property
testSpans = do
  first <- newSource (SourceName "same.pudu") "same"
  second <- newSource (SourceName "same.pudu") "same"
  let at = emptySpan first
      other = emptySpan second
      generated = generatedSpan 1 at other
      next = generatedSpan 2 at other
      info = TypeInfo (Map.singleton (0, 0) integerType)
        (Map.fromList [(at, integerType), (generated, boolType)])
  pure $ case nativeTypes (Just info) [] of
    Nothing -> counterexample "type facts missing" (False === True)
    Just facts -> conjoin
      [ typeForSpan facts at === Just (CoreIntegerType PlatformSigned)
      , typeForSpan facts generated === Just CoreBoolType
      , typeForSpan facts other === Nothing
      , typeForSpan facts next === Nothing
      ]

testMissing :: IO Property
testMissing = do
  source <- newSource (SourceName "Main.pudu")
    "module Main\nfn helper(value: Int) -> Int { return value }\nfn main() -> Int { let held: Int = helper(1)\n return 0 }\n"
  checked <- runCompile source
  pure $ case (hasErrors (compileDiagnostics checked), compileModule checked) of
    (False, Just parsed) -> conjoin
      [ case lowerProgram "main" Nothing parsed of
          LowerRefused [diagnostic] -> conjoin
            [ diagnosticCodeText (diagnosticCode diagnostic) === "E6001"
            , diagnosticSpan diagnostic === moduleSpan parsed
            ]
          other -> counterexample (show other) (False === True)
      , case lowerProgram "main"
          (nativeTypes (Just (TypeInfo Map.empty Map.empty)) (compileSchemes checked)) parsed of
          LowerRefused [diagnostic] -> diagnosticCodeText (diagnosticCode diagnostic) === "E6001"
          other -> counterexample (show other) (False === True)
      , case lowerProgram "main" (nativeTypes (compileTypes checked) []) parsed of
          LowerRefused [diagnostic] -> diagnosticCodeText (diagnosticCode diagnostic) === "E6001"
          other -> counterexample (show other) (False === True)
      ]
    _ -> counterexample (show (compileDiagnostics checked)) (False === True)
