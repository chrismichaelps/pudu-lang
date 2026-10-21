{-| @Test.Backend.LowerTypesSpec — canonical solved native fact boundaries. -}
module Pudu.Backend.LowerTypesSpec (lowerTypesProperties) where

import qualified Data.Text as Text
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Compiler.Lower (LowerResult (..), lowerModule)
import Pudu.Compiler.Lower.Types (formedCoreType, nativeTypes, typeForSpan)
import Pudu.Core (CoreType (..), CoreModule (..), CoreFunction (..), CoreBlock (..), CoreExpression (..), CoreExpressionShape (..))
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText, diagnosticSpan, hasErrors)
import Pudu.Frontend.Syntax (Module (..), ModuleName (..))
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned, PlatformUnsigned, SignedKind, UnsignedKind))
import Pudu.Source (SourceName (..), emptySpan, generatedSpan, newSource, sourceText, spanStart, spanEnd, unOffset)
import Pudu.Type (TypeInfo (..))
import Pudu.Type.Value (NominalId (..), Type (..), boolType, integerType, stringType)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

lowerTypesProperties :: [(String, IO Property)]
lowerTypesProperties =
  [ ("native representation uses canonical solved identities", pure testCanonical)
  , ("native type facts retain source and generated span identities", testSpans)
  , ("native lowering refuses missing analysis facts", testMissing)
  , ("native operator traps retain exact spans and messages", testTraps)
  , ("native operator traps require settled operand facts", testTrapFacts)
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
  , formedCoreType (NominalType "Int8" []) === Just (CoreIntegerType (SignedKind 8))
  , formedCoreType (NominalType "Int16" []) === Just (CoreIntegerType (SignedKind 16))
  , formedCoreType (NominalType "Int32" []) === Just (CoreIntegerType (SignedKind 32))
  , formedCoreType (NominalType "Int64" []) === Just (CoreIntegerType (SignedKind 64))
  , formedCoreType (NominalType (NominalId (Just (ModuleName ("User" :| []))) "Int8") []) === Nothing
  , formedCoreType (NominalType "Int128" []) === Just (CoreIntegerType (SignedKind 128))
  , formedCoreType (NominalType "UInt" []) === Just (CoreIntegerType PlatformUnsigned)
  , formedCoreType (NominalType "UInt8" []) === Just (CoreIntegerType (UnsignedKind 8))
  , formedCoreType (NominalType "UInt16" []) === Just (CoreIntegerType (UnsignedKind 16))
  , formedCoreType (NominalType "UInt32" []) === Just (CoreIntegerType (UnsignedKind 32))
  , formedCoreType (NominalType "UInt64" []) === Just (CoreIntegerType (UnsignedKind 64))
  , formedCoreType (NominalType (NominalId (Just (ModuleName ("User" :| []))) "UInt64") []) === Nothing
  , formedCoreType (NominalType "UInt128" []) === Just (CoreIntegerType (UnsignedKind 128))
  , formedCoreType (NominalType (NominalId (Just (ModuleName ("User" :| []))) "Int128") []) === Nothing
  , formedCoreType (NominalType (NominalId (Just (ModuleName ("User" :| []))) "UInt128") []) === Nothing
  , formedCoreType (NominalType "Int128" [integerType]) === Nothing
  , formedCoreType (NominalType "UInt128" [integerType]) === Nothing
  , formedCoreType (NominalType "UInt8" [integerType]) === Nothing
  , formedCoreType (NominalType "Int8" [integerType]) === Nothing
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
      [ case lowerModule "main" Nothing parsed of
          LowerRefused [diagnostic] -> conjoin
            [ diagnosticCodeText (diagnosticCode diagnostic) === "E6001"
            , diagnosticSpan diagnostic === moduleSpan parsed
            ]
          other -> counterexample (show other) (False === True)
      , case lowerModule "main"
          (nativeTypes (Just (TypeInfo Map.empty Map.empty)) (compileSchemes checked)) parsed of
          LowerRefused [diagnostic] -> diagnosticCodeText (diagnosticCode diagnostic) === "E6001"
          other -> counterexample (show other) (False === True)
      , case lowerModule "main" (nativeTypes (compileTypes checked) []) parsed of
          LowerRefused [diagnostic] -> diagnosticCodeText (diagnosticCode diagnostic) === "E6001"
          other -> counterexample (show other) (False === True)
      ]
    _ -> counterexample (show (compileDiagnostics checked)) (False === True)

testTraps :: IO Property
testTraps = conjoin <$> mapM check
  [ ("() + ()", "cannot apply + to a unit and a unit", 2)
  , ("true + false", "unsupported operator +", 2)
  , ("-false", "cannot apply - to a bool", 1)
  , ("() << 1", "cannot apply << to a unit and a Int", 2)
  ]
 where
  check (expression, expected, count) = do
    source <- newSource (SourceName "Main.pudu") ("module Main\nfn main() { " <> expression <> " }\n")
    checked <- runCompile source
    pure $ case (hasErrors (compileDiagnostics checked), compileModule checked) of
      (False, Just parsed) -> case lowerModule "main" (nativeTypes (compileTypes checked) (compileSchemes checked)) parsed of
        Lowered core | [entry] <- coreModuleFunctions core
          , Just result <- coreBlockResult (coreFunctionBody entry)
          , CoreOperatorFailure message operands <- coreExpressionShape result ->
              let at = coreExpressionSpan result
               in conjoin
                    [ coreExpressionType result === CoreNeverType
                    , message === expected
                    , length operands === count
                    , Text.take (unOffset (spanEnd at) - unOffset (spanStart at))
                        (Text.drop (unOffset (spanStart at)) (sourceText source)) === expression
                    ]
        other -> counterexample (show other) (False === True)
      _ -> counterexample (show (compileDiagnostics checked)) (False === True)

testTrapFacts :: IO Property
testTrapFacts = do
  source <- newSource (SourceName "Main.pudu") "module Main\nfn main() { () + () }\n"
  checked <- runCompile source
  pure $ case (hasErrors (compileDiagnostics checked), compileModule checked) of
    (False, Just parsed) -> case lowerModule "main"
        (nativeTypes (Just (TypeInfo Map.empty Map.empty)) (compileSchemes checked)) parsed of
      LowerRefused [diagnostic] -> diagnosticCodeText (diagnosticCode diagnostic) === "E6001"
      other -> counterexample (show other) (False === True)
    _ -> counterexample (show (compileDiagnostics checked)) (False === True)
