{-| @Test.Eval.NamedSumSpec — owned named data before executable publication. -}
module Pudu.Eval.NamedSumSpec (namedSumProperties) where

import qualified Data.ByteString as BS
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Set as Set
import Pudu.Cache.Persist (decodeWith, encodeFor)
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText, diagnosticSpan)
import qualified Pudu.Eval as Eval
import Pudu.Eval.Env (bind, recordVariantOwner)
import Pudu.Eval.Frozen (Frozen, freeze, thaw)
import Pudu.Eval.Loop (receiverOwners)
import Pudu.Eval.Match (matchPattern)
import Pudu.Eval.Operator (readMember)
import Pudu.Eval.Order (comparableValue)
import Pudu.Eval.Place (plainPlace, storePlace)
import Pudu.Eval.Render (renderValue, valueKind)
import Pudu.Eval.Value (Builtin (PanicBuiltin), OrdValue (..), Value (..), compareValues, intOf)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree (Block (..), Expression (..), FieldPattern (..), Literal (..), Pattern (..), Statement (..))
import Pudu.IntegerLiteral (IntegerKind (SignedKind))
import Pudu.Source (SourceName (..), emptySpan, newSource)
import Test.QuickCheck (Gen, Property, arbitrary, conjoin, counterexample, forAll, property, (===))

namedSumProperties :: [(String, IO Property)]
namedSumProperties =
  [ ("named sum values retain owner tag and distinct shape", identity)
  , ("named sum values persist without erasing nested ownership", frozen)
  , ("named sum patterns test canonical owners and named fields", patterns)
  , ("named sum fields places and iteration retain their owner", access)
  ]

identity :: IO Property
identity = pure $ forAll (arbitrary :: Gen Int) $ \number ->
  let fields = [("value", intOf (toInteger number))]
      first = NamedSumValue "First.Item" "Chosen" fields
      second = NamedSumValue "Second.Item" "Chosen" fields
      other = NamedSumValue "First.Item" "Other" fields
      record = RecordValue "First.Item.Chosen" fields
      positional = SumValue "First.Item" "Chosen" (map snd fields)
      values = [first, second, other, record, positional]
   in conjoin
      [ first === NamedSumValue "First.Item" "Chosen" fields
      , conjoin [counterexample "owner/tag/shape collision" (property (first /= value && compareValues first value /= EQ))
          | value <- [second, other, record, positional]]
      , Set.size (Set.fromList (map OrdValue values)) === 5
      , property (comparableValue first)
      , property (not (comparableValue (NamedSumValue "First.Item" "Chosen" [("value", BuiltinValue PanicBuiltin)])))
      , renderValue first === "Chosen{value: " <> renderValue (intOf (toInteger number)) <> "}"
      , valueKind first === "Chosen"
      ]

frozen :: IO Property
frozen = do
  source <- newSource (SourceName "named-sum-storage") ""
  pure $ forAll (arbitrary :: Gen Int) $ \number ->
    let nested = NamedSumValue "Second.Item" "Chosen" [("value", intOf (toInteger number))]
        value = NamedSumValue "First.Item" "Chosen"
          [("nested", nested), ("record", RecordValue "First.Item.Chosen" []), ("sum", SumValue "First.Item" "Empty" [])]
     in case freeze value of
          Nothing -> counterexample "plain named data refused" False
          Just stored ->
            let bytes = encodeFor source stored
             in conjoin
                [ (thaw <$> decodeWith source bytes) === Just value
                , conjoin [counterexample ("accepted stored prefix " <> show count)
                    (decodeWith source (BS.take count bytes) === (Nothing :: Maybe Frozen))
                    | count <- [0 .. BS.length bytes - 1]]
                , freeze (NamedSumValue "First.Item" "Chosen" [("value", BuiltinValue PanicBuiltin)]) === Nothing
                ]

patterns :: IO Property
patterns = do
  source <- newSource (SourceName "named-sum-patterns") ""
  let at = emptySpan source
      field = Located at (FieldPattern (Located at "value") (Just (Located at (LiteralPattern (IntegerValue "7")))))
      named owner label = Just (ModuleName ("::sum::" :| [owner, label]))
      patternFor path = Located at (RecordPattern path [field] False)
      value = NamedSumValue "First.Item" "Chosen" [("value", IntValue (SignedKind 8) 7)]
      expected = Just []
  pure $ conjoin
    [ matchPattern (patternFor (named "First.Item" "Chosen")) value === expected
    , matchPattern (patternFor (named "Second.Item" "Chosen")) value === Nothing
    , matchPattern (patternFor (named "First.Item" "Other")) value === Nothing
    , matchPattern (patternFor Nothing) value === expected
    , matchPattern (patternFor (Just (ModuleName ("Chosen" :| [])))) value === expected
    , matchPattern (patternFor (Just (ModuleName ("First.Item.Chosen" :| [])))) value === Nothing
    , matchPattern (patternFor (named "First.Item" "Chosen")) (RecordValue "Chosen" [("value", intOf 7)]) === Nothing
    , matchPattern (patternFor (named "First.Item" "Chosen")) (NamedSumValue "First.Item" "Chosen" []) === Nothing
    , matchPattern (patternFor (named "First.Item" "Chosen")) (NamedSumValue "First.Item" "Chosen" [("value", intOf 8)]) === Nothing
    , matchPattern (Located at (ConstructorPattern (ModuleName ("First.Item.Chosen" :| [])) [])) value === Nothing
    ]

access :: IO Property
access = do
  source <- newSource (SourceName "named-sum-access") ""
  let at = emptySpan source
      value = NamedSumValue "First.Item" "Chosen" [("first", intOf 1), ("second", intOf 2)]
      name text = Located at (NameExpression (text :| []))
      member target field = Located at (MemberExpression target (Located at field))
      nested = NamedSumValue "Outer.Item" "Wrapped" [("inner", value)]
      changed = NamedSumValue "First.Item" "Chosen" [("first", intOf 7), ("second", intOf 2)]
      assignment = Located at (BinaryExpression (name "seen") "="
        (Located at (BinaryExpression
          (Located at (BinaryExpression (name "seen") "*" (Located at (LiteralExpression (IntegerValue "10")))))
          "+" (name "part"))))
      loop = Located at (ForExpression Nothing (Located at (BindingPattern (Located at "part")))
        (name "held") (Located at (Block [Located at (ExpressionStatement assignment)] Nothing)))
  readBack <- Eval.runWithEffects True (readMember at value "first")
  owner <- Eval.runWithEffects True $ do
    recordVariantOwner "Chosen" "Second.Item"
    TupleValue . map StrValue <$> receiverOwners value
  updated <- Eval.runWithEffects True $ do
    bind "held" value
    case plainPlace (member (name "held") "first") of
      Nothing -> pure UnitValue
      Just place -> storePlace place (intOf 7) >> Eval.evaluate (name "held")
  nestedUpdate <- Eval.runWithEffects True $ do
    bind "outer" nested
    case plainPlace (member (member (name "outer") "inner") "first") of
      Nothing -> pure UnitValue
      Just place -> storePlace place (intOf 7) >> Eval.evaluate (name "outer")
  nestedRead <- Eval.runWithEffects True $ do
    bind "outer" nested
    Eval.evaluate (member (member (name "outer") "inner") "second")
  iterated <- Eval.runWithEffects True $ do
    bind "held" value
    bind "seen" (intOf 0)
    _ <- Eval.evaluate loop
    Eval.evaluate (name "seen")
  missing <- Eval.runWithEffects True (readMember at value "missing")
  pure $ conjoin
    [ Eval.outcomeValue readBack === Just (intOf 1)
    , Eval.outcomeValue owner === Just (TupleValue [StrValue "First.Item"])
    , Eval.outcomeValue updated === Just changed
    , Eval.outcomeValue nestedUpdate === Just (NamedSumValue "Outer.Item" "Wrapped" [("inner", changed)])
    , Eval.outcomeValue nestedRead === Just (intOf 2)
    , Eval.outcomeValue iterated === Just (intOf 12)
    , Eval.outcomeValue missing === Nothing
    , [(diagnosticCodeText (diagnosticCode finding), diagnosticSpan finding)
        | finding <- Eval.outcomeDiagnostics missing] === [("E7001", at)]
    ]
