{-| @Test.Lsp.Json — the JSON the protocol depends on, read and written -}
module Pudu.Lsp.JsonSpec (jsonProperties) where

import qualified Data.Text as Text
import Pudu.Lsp.Json (Json (..), encode, integerOf, lookupField, parse, textOf)
import Test.QuickCheck
  ( Gen
  , Property
  , chooseInt
  , conjoin
  , counterexample
  , elements
  , forAll
  , oneof
  , property
  , resize
  , sized
  , (===)
  )

jsonProperties :: [(String, IO Property)]
jsonProperties =
  [ ("every value survives encoding and parsing", testRoundTrip)
  , ("the shapes a request arrives in parse", testRequestShapes)
  , ("escapes decode to the scalars they name", testEscapes)
  , ("numbers read as written", testNumbers)
  , ("malformed input is refused rather than guessed at", testMalformed)
  , ("whole numbers encode without a fractional part", testWholeNumbers)
  ]

{-| The property the protocol rests on: what the server writes, a client reads
    as the same value, and the reverse. -}
testRoundTrip :: IO Property
testRoundTrip =
  pure $ forAll values $ \value ->
    counterexample (Text.unpack (encode value)) (parse (encode value) === Just value)

{-| Bounded so a counterexample stays readable; the laws do not depend on
    depth. -}
values :: Gen Json
values = sized (\size -> resize (min size 4) generate)
 where
  generate = sized $ \size ->
    if size <= 0
      then leaf
      else
        oneof
          [ leaf
          , JsonArray <$> shorter (resize 3 (listOf' generate))
          , JsonObject <$> shorter (resize 3 (listOf' ((,) <$> names <*> generate)))
          ]
  leaf =
    oneof
      [ pure JsonNull
      , JsonBool <$> elements [True, False]
      , JsonNumber . fromIntegral <$> chooseInt (-1000, 1000)
      , JsonText <$> contents
      ]
  shorter = resize 2
  listOf' item = do
    count <- chooseInt (0, 3)
    sequence (replicate count item)
  names = elements ["id", "method", "params", "uri", "line", "character", "ünïcode"]
  contents =
    elements
      [ ""
      , "plain"
      , "with \"quotes\""
      , "with \\ backslash"
      , "with\nnewline\ttab"
      , "ünïcode and emoji \128512"
      , "file:///pudu-fixtures/a b.pudu"
      ]

{-| The exact shapes the server has to read off the wire. -}
testRequestShapes :: IO Property
testRequestShapes =
  pure $ conjoin
    [ counterexample "a request"
        ( parse "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}"
            === Just
              ( JsonObject
                  [ ("jsonrpc", JsonText "2.0")
                  , ("id", JsonNumber 1)
                  , ("method", JsonText "initialize")
                  , ("params", JsonObject [])
                  ]
              )
        )
    , counterexample "a position"
        ( (parse "{\"line\":3,\"character\":11}" >>= lookupField "character" >>= integerOf)
            === Just 11
        )
    , counterexample "a string identifier, which the protocol also allows"
        ( (parse "{\"id\":\"a-1\"}" >>= lookupField "id" >>= textOf) === Just "a-1" )
    , counterexample "an absent member is nothing rather than an error"
        ( (parse "{\"id\":1}" >>= lookupField "params") === Nothing )
    , counterexample "nesting"
        ( (parse "{\"a\":{\"b\":[1,{\"c\":true}]}}" >>= lookupField "a" >>= lookupField "b")
            === Just (JsonArray [JsonNumber 1, JsonObject [("c", JsonBool True)]])
        )
    , counterexample "whitespace between every token" (parse spacious === Just spaced)
    , counterexample "empty containers" (parse "{\"a\":[],\"b\":{}}" === Just emptyPair)
    ]
 where
  spacious = "  {  \"a\"  :  [  1  ,  2  ]  }  "
  spaced = JsonObject [("a", JsonArray [JsonNumber 1, JsonNumber 2])]
  emptyPair = JsonObject [("a", JsonArray []), ("b", JsonObject [])]

testEscapes :: IO Property
testEscapes =
  pure $ conjoin
    [ decodes "\"\\n\"" "\n"
    , decodes "\"\\t\"" "\t"
    , decodes "\"\\\\\"" "\\"
    , decodes "\"\\\"\"" "\""
    , decodes "\"\\/\"" "/"
    , decodes "\"\\u0041\"" "A"
    , counterexample "a scalar below space, which a client may send escaped"
        (decodes "\"\\u001f\"" "\31")
    , counterexample "a surrogate pair joins into one scalar"
        (decodes "\"\\ud83d\\ude00\"" "\128512")
    , counterexample "an unpaired high surrogate is refused"
        (parse "\"\\ud83d\"" === Nothing)
    , counterexample "an unpaired low surrogate is refused"
        (parse "\"\\ude00\"" === Nothing)
    , counterexample "an unknown escape is refused" (parse "\"\\q\"" === Nothing)
    , counterexample "a short hex escape is refused" (parse "\"\\u12\"" === Nothing)
    ]
 where
  decodes source expected = parse source === Just (JsonText expected)

testNumbers :: IO Property
testNumbers =
  pure $ conjoin
    [ parse "0" === Just (JsonNumber 0)
    , parse "-7" === Just (JsonNumber (-7))
    , parse "1.5" === Just (JsonNumber 1.5)
    , parse "1e3" === Just (JsonNumber 1000)
    , parse "1E+3" === Just (JsonNumber 1000)
    , parse "1.5e-1" === Just (JsonNumber 0.15)
    , counterexample "a bare sign is not a number" (parse "-" === Nothing)
    , counterexample "a leading point is not a number" (parse ".5" === Nothing)
    , counterexample "a trailing point is not a number" (parse "1." === Nothing)
    , counterexample "an exponent needs digits" (parse "1e" === Nothing)
    , counterexample "a whole number reads as one" (integerOf (JsonNumber 3) === Just 3)
    , counterexample "a fractional position is malformed, not rounded"
        (integerOf (JsonNumber 3.5) === Nothing)
    ]

{-| A framing bug must surface rather than be absorbed, so anything left over
    after a complete value is a failure. -}
testMalformed :: IO Property
testMalformed =
  pure $ conjoin
    [ parse "" === Nothing
    , parse "{" === Nothing
    , parse "[1,]" === Nothing
    , parse "{\"a\"}" === Nothing
    , parse "{\"a\":}" === Nothing
    , parse "{a:1}" === Nothing
    , parse "tru" === Nothing
    , counterexample "trailing content is a framing bug" (parse "{} {}" === Nothing)
    , counterexample "an unterminated string" (parse "\"abc" === Nothing)
    ]

{-| A position written `3.0` is legal JSON that some clients then reject. -}
testWholeNumbers :: IO Property
testWholeNumbers =
  pure $ conjoin
    [ encode (JsonNumber 3) === "3"
    , encode (JsonNumber (-3)) === "-3"
    , encode (JsonNumber 0) === "0"
    , counterexample "a fractional number keeps its point"
        (property (Text.isInfixOf "." (encode (JsonNumber 1.5))))
    ]
