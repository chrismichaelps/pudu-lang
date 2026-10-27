{-| @Test.Backend.LowerTypesSpec — canonical solved native fact boundaries. -}
module Pudu.Backend.LowerTypesSpec (lowerTypesProperties) where

import qualified Data.Text as Text
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import GHC.Float (castDoubleToWord64)
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Compiler.Lower (LowerResult (..), lowerModule, lowerModuleFolded)
import Pudu.Compiler.Lower.Types (formedCoreType, nativeTypes, typeForSpan, sharedReferenceTarget)
import Pudu.Core (CoreType (..), CoreModule (..), CoreFunction (..), CoreBlock (..), CoreExpression (..), CoreExpressionShape (..))
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText, diagnosticSpan, hasErrors)
import Pudu.Eval.Frozen (thaw)
import Pudu.Eval.Value (Value (FloatValue))
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
  , ("native constants require represented folded products at their use", testConstantFacts)
  , ("native shared references retain checked fact and carrier boundaries", testReferenceFacts)
  ]

testReferenceFacts :: IO Property
testReferenceFacts = conjoin <$> traverse check
  [ ( "fn change(value: &mut Int) -> () { *value = *value + 1 }\nfn main() -> Int { var n = 0\n change(&mut n)\n n }", False )
  , ( "fn main() -> Int { let ratio = 1.5d\n let loan = &ratio\n 0 }", False )
  , ( "fn main() -> Int { let number = 1\n let loan = &number\n *loan }", True )
  ]
 where
  check (body, removeFacts) = do
    source <- newSource (SourceName "Main.pudu") ("module Main\n" <> body <> "\n")
    checked <- runCompile source
    pure $ case (hasErrors (compileDiagnostics checked), compileModule checked) of
      (False, Just parsed) ->
        let facts = if removeFacts then Just (TypeInfo Map.empty Map.empty) else compileTypes checked
         in case lowerModule "main" (nativeTypes facts (compileSchemes checked)) parsed of
              LowerRefused [diagnostic] -> conjoin
                [ diagnosticCodeText (diagnosticCode diagnostic) === "E6001"
                , let at = diagnosticSpan diagnostic in
                    counterexample "a refused reference has a source span" (unOffset (spanEnd at) > unOffset (spanStart at))
                ]
              other -> counterexample (show other) (False === True)
      _ -> counterexample (show (compileDiagnostics checked)) (False === True)

testConstantFacts :: IO Property
testConstantFacts = do
  results <- traverse check [("7", True), ("1.5d", False), ("[1, 2]", False), ("fn() => 1", False)]
  floating <- traverse checkFloat [("0.1f32", Just 0x3fb99999a0000000), ("-0.0", Just 0x8000000000000000), ("0.0 / 0.0", Nothing)]
  broken <- newSource (SourceName "Main.pudu") "module Main\nconst BAD = 1 / 0\nfn main() -> Int { 0 }\n" >>= runCompile
  pure $ conjoin (counterexample "constant failure remains a compile diagnostic"
    (hasErrors (compileDiagnostics broken) === True) : results <> floating)
 where
  checkFloat (initializer, golden) = do
    source <- newSource (SourceName "Main.pudu")
      ("module Main\nconst HELD = " <> initializer <> "\nfn main() { HELD }\n")
    checked <- runCompile source
    pure $ case (hasErrors (compileDiagnostics checked), compileModule checked, thaw <$> Map.lookup "HELD" (compileFolded checked)) of
      (False, Just parsed, Just (FloatValue width number)) ->
        case lowerModuleFolded "main" (nativeTypes (compileTypes checked) (compileSchemes checked)) (compileFolded checked) parsed of
          Lowered core | [entry] <- coreModuleFunctions core
            , Just result <- coreBlockResult (coreFunctionBody entry)
            , CoreFloatLiteral actual bits <- coreExpressionShape result -> conjoin
                [ actual === width, bits === castDoubleToWord64 number
                , maybe (True === True) (bits ===) golden ]
          other -> counterexample (show other) (False === True)
      _ -> counterexample (show (compileDiagnostics checked)) (False === True)
  check (initializer, represented) = do
    source <- newSource (SourceName "Main.pudu")
      ("module Main\nconst HELD = " <> initializer <> "\nfn main() -> Int {\n  let value = HELD\n  0\n}\n")
    checked <- runCompile source
    pure $ case (hasErrors (compileDiagnostics checked), compileModule checked) of
      (False, Just parsed) ->
        let facts = nativeTypes (compileTypes checked) (compileSchemes checked)
            supplied = lowerModuleFolded "main" facts (compileFolded checked) parsed
            refusedAtUse result = case result of
              LowerRefused [diagnostic] -> conjoin
                [ diagnosticCodeText (diagnosticCode diagnostic) === "E6001"
                , let at = diagnosticSpan diagnostic in
                    Text.take (unOffset (spanEnd at) - unOffset (spanStart at))
                      (Text.drop (unOffset (spanStart at)) (sourceText source)) === "HELD"
                ]
              other -> counterexample (show other) (False === True)
         in conjoin
              [ refusedAtUse (lowerModule "main" facts parsed)
              , if represented then case supplied of
                  Lowered _ -> True === True
                  other -> counterexample (show other) (False === True)
                else refusedAtUse supplied
              ]
      _ -> counterexample (show (compileDiagnostics checked)) (False === True)

testCanonical :: Property
testCanonical = conjoin
  [ formedCoreType integerType === Just (CoreIntegerType PlatformSigned)
  , formedCoreType (ReferenceTypeValue False integerType) === Just (CoreIntegerType PlatformSigned)
  , formedCoreType (ReferenceTypeValue True integerType) === Nothing
  , formedCoreType (ReferenceTypeValue False (NominalType "Decimal" [])) === Nothing
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
      reference = generatedSpan 3 at other
      info = TypeInfo (Map.singleton (0, 0) integerType)
        (Map.fromList [(at, integerType), (generated, boolType), (reference, ReferenceTypeValue False integerType)])
  pure $ case nativeTypes (Just info) [] of
    Nothing -> counterexample "type facts missing" (False === True)
    Just facts -> conjoin
      [ typeForSpan facts at === Just (CoreIntegerType PlatformSigned)
      , typeForSpan facts generated === Just CoreBoolType
      , typeForSpan facts other === Nothing
      , typeForSpan facts next === Nothing
      , sharedReferenceTarget facts reference === Just (CoreIntegerType PlatformSigned)
      , sharedReferenceTarget facts generated === Nothing
      , sharedReferenceTarget facts (generatedSpan 3 other at) === Nothing
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
