{-| What a foreign result is allowed to become.

    A carrier that does not match its declaration used to fall through to a
    generic arm and answer with a value of some other type, and a record was
    rebuilt from whatever fields arrived. These hold conversion to the one shape
    the declaration names, so a boundary mismatch is a diagnostic rather than a
    plausible-looking value. -}
module Pudu.Eval.Foreign.ResultSpec (resultProperties) where

import Data.Int (Int64)
import Data.Word (Word64)
import Pudu.Eval.Foreign.Result (ConversionFailure (..), convertForeignValue)
import Pudu.Eval.Value (Value (..))
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.Foreign.Call (CrossedValue (..))
import Pudu.Foreign.Crossing (Crossing (..))
import Pudu.IntegerLiteral (IntegerKind (..))
import Test.QuickCheck (Property, conjoin, counterexample, forAll, property, (===))
import qualified Test.QuickCheck as QuickCheck

resultProperties :: [(String, IO Property)]
resultProperties =
  [ ("a carrier outside the declaration is refused, not converted", testCategoryMismatch)
  , ("a record is refused unless every field is the declared one", testRecordShape)
  , ("a record field carrying a resource is refused", testResourceField)
  , ("a nested record is rebuilt at every depth", testNestedRecord)
  , ("absent text names the field that declared it", testMissingText)
  , ("an unsigned 64 result keeps the value the library sent", testUnsignedRoundTrip)
  , ("an integer outside its declared width is refused", testWidthRange)
  ]

converts :: Crossing -> CrossedValue -> Either ConversionFailure Value
converts = convertForeignValue "result"

{-| An integer carrier is not a floating result, and neither is a stand-in for
    the other. Both answered before this. -}
testCategoryMismatch :: IO Property
testCategoryMismatch =
  pure
    ( conjoin
        [ labelled "float declared, integer carried" $
            converts (FloatingCrossing 64) (CrossedInteger 3) === Left InvalidShape
        , labelled "integer declared, float carried" $
            converts (SignedCrossing 32) (CrossedDouble 1.5) === Left InvalidShape
        , labelled "bool declared, float carried" $
            converts BooleanCrossing (CrossedDouble 1) === Left InvalidShape
        , labelled "text declared, integer carried" $
            converts TextCrossing (CrossedInteger 0) === Left InvalidShape
        , labelled "record declared, scalar carried" $
            converts (RecordCrossing "P" [("x", SignedCrossing 32)]) (CrossedInteger 1)
              === Left InvalidShape
        , labelled "integer declared, record carried" $
            converts (SignedCrossing 32) (CrossedRecord "P" [("x", CrossedInteger 1)])
              === Left InvalidShape
        , labelled "an integer result still converts" $
            converts (SignedCrossing 32) (CrossedInteger 7)
              === Right (IntValue (SignedKind 32) 7)
        , labelled "a floating result still converts" $
            converts (FloatingCrossing 32) (CrossedDouble 0.5)
              === Right (FloatValue Float32Width 0.5)
        ]
    )

{-| A record arrives flat, and only the declaration says what it should have
    been. A shorter one is a mismatch rather than a smaller record. -}
testRecordShape :: IO Property
testRecordShape =
  pure
    ( conjoin
        [ labelled "every field present and named" $
            converts declared (CrossedRecord "Point" [("x", CrossedInteger 1), ("y", CrossedInteger 2)])
              === Right (RecordValue "Point" [("x", IntValue (SignedKind 32) 1), ("y", IntValue (SignedKind 32) 2)])
        , labelled "a missing field" $
            converts declared (CrossedRecord "Point" [("x", CrossedInteger 1)]) === Left InvalidShape
        , labelled "a surplus field" $
            converts
              declared
              ( CrossedRecord
                  "Point"
                  [("x", CrossedInteger 1), ("y", CrossedInteger 2), ("z", CrossedInteger 3)]
              )
              === Left InvalidShape
        , labelled "a renamed field" $
            converts declared (CrossedRecord "Point" [("x", CrossedInteger 1), ("w", CrossedInteger 2)])
              === Left InvalidShape
        , labelled "fields in another order" $
            converts declared (CrossedRecord "Point" [("y", CrossedInteger 2), ("x", CrossedInteger 1)])
              === Left InvalidShape
        , labelled "another record's name" $
            converts declared (CrossedRecord "Other" [("x", CrossedInteger 1), ("y", CrossedInteger 2)])
              === Left InvalidShape
        , labelled "a field carrying the wrong category" $
            converts declared (CrossedRecord "Point" [("x", CrossedInteger 1), ("y", CrossedDouble 2)])
              === Left InvalidShape
        ]
    )
 where
  declared = RecordCrossing "Point" [("x", SignedCrossing 32), ("y", SignedCrossing 32)]

{-| A field is not the place a resource, a run of bytes, or nothing at all can
    arrive: each carries an obligation a field has no way to hold. -}
testResourceField :: IO Property
testResourceField =
  pure
    ( conjoin
        [ labelled "a handle field" $
            converts
              (RecordCrossing "Holder" [("held", HandleCrossing "Box")])
              (CrossedRecord "Holder" [("held", CrossedHandle "Box" 4096)])
              === Left InvalidShape
        , labelled "a bytes field" $
            converts
              (RecordCrossing "Holder" [("held", BytesCrossing)])
              (CrossedRecord "Holder" [("held", CrossedInteger 0)])
              === Left InvalidShape
        , labelled "a unit field" $
            converts
              (RecordCrossing "Holder" [("held", NothingCrossing)])
              (CrossedRecord "Holder" [("held", CrossedInteger 0)])
              === Left InvalidShape
        ]
    )

testNestedRecord :: IO Property
testNestedRecord =
  pure
    ( converts
        (RecordCrossing "Outer" [("inner", RecordCrossing "Inner" [("n", SignedCrossing 32)])])
        (CrossedRecord "Outer" [("inner", CrossedRecord "Inner" [("n", CrossedInteger 5)])])
        === Right
          (RecordValue "Outer" [("inner", RecordValue "Inner" [("n", IntValue (SignedKind 32) 5)])])
    )

{-| A null text pointer is an absence with a name, so the diagnostic can say
    which field the library left empty rather than that some text was missing. -}
testMissingText :: IO Property
testMissingText =
  pure
    ( conjoin
        [ labelled "the result itself" $
            converts TextCrossing CrossedNoText === Left (MissingText "result")
        , labelled "a field, under its own name" $
            convertForeignValue
              "result"
              (RecordCrossing "Named" [("label", TextCrossing)])
              (CrossedRecord "Named" [("label", CrossedNoText)])
              === Left (MissingText "label")
        ]
    )

{-| The bridge carries every integer in a signed slot, so the top bit of a
    UInt64 arrives negative and has to be read back as the library meant it. -}
testUnsignedRoundTrip :: IO Property
testUnsignedRoundTrip =
  pure
    ( conjoin
        [ property . forAll QuickCheck.arbitrary $ \(held :: Int64) ->
            converts (UnsignedCrossing 64) (CrossedInteger held)
              === Right (IntValue (UnsignedKind 64) (toInteger (fromIntegral held :: Word64)))
        , labelled "the whole range is above zero" $
            converts (UnsignedCrossing 64) (CrossedInteger (-1))
              === Right (IntValue (UnsignedKind 64) 18446744073709551615)
        , labelled "a signed 64 keeps its sign" $
            converts (SignedCrossing 64) (CrossedInteger (-1))
              === Right (IntValue (SignedKind 64) (-1))
        ]
    )

{-| A narrow declaration is a promise about the value, not only about the
    storage it travelled in. -}
testWidthRange :: IO Property
testWidthRange =
  pure
    ( conjoin
        [ labelled "signed 8 at its edges" $
            conjoin
              [ converts (SignedCrossing 8) (CrossedInteger 127)
                  === Right (IntValue (SignedKind 8) 127)
              , converts (SignedCrossing 8) (CrossedInteger (-128))
                  === Right (IntValue (SignedKind 8) (-128))
              , converts (SignedCrossing 8) (CrossedInteger 128) === Left InvalidShape
              , converts (SignedCrossing 8) (CrossedInteger (-129)) === Left InvalidShape
              ]
        , labelled "unsigned 8 refuses a negative carrier" $
            conjoin
              [ converts (UnsignedCrossing 8) (CrossedInteger 255)
                  === Right (IntValue (UnsignedKind 8) 255)
              , converts (UnsignedCrossing 8) (CrossedInteger 256) === Left InvalidShape
              , converts (UnsignedCrossing 8) (CrossedInteger (-1)) === Left InvalidShape
              ]
        , labelled "a width the boundary does not carry" $
            converts (SignedCrossing 24) (CrossedInteger 1) === Left InvalidShape
        ]
    )

labelled :: String -> Property -> Property
labelled = counterexample
