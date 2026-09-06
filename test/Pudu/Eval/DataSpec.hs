{-| @Test.Eval.DataSpec — evaluation of records, variants, tuples, maps, sets, and text operations -}
module Pudu.Eval.DataSpec
  ( dataProperties
  , testArrayConcat
  , testData
  , testInterpolation
  , testKeyed
  , testTextMethods
  ) where

import Test.QuickCheck (Property, conjoin, counterexample, (===))

import Pudu.Eval.Common
  ( codesOf
  , evaluate
  , evaluateStatements
  , evaluateWith
  , runProgram
  )

dataProperties :: [(String, IO Property)]
dataProperties =
  [ ("sum and record values construct and destructure", testData)
  , ("built-in text methods answer with new values", testTextMethods)
  , ("array concatenation joins two arrays", testArrayConcat)
  , ("maps and sets keep their contents in key order", testKeyed)
  , ("interpolated strings render their holes", testInterpolation)
  ]

testData :: IO Property
testData = do
  variant <- evaluateWith
    [ "type Outcome ="
    , "  | Ok(Int)"
    , "  | Err(Str)"
    ]
    "match Ok(3) { case Ok(value) => value * 2 case Err(_) => 0 }"
  qualified <- evaluateWith
    [ "type Outcome ="
    , "  | Ok(Int)"
    , "  | Err(Str)"
    ]
    "match Outcome.Err(\"stop\") { case Ok(_) => \"ok\" case Err(reason) => reason }"
  record <- evaluateWith
    [ "type User = { id: Int, name: Str }" ]
    "User{id: 3, name: \"ada\"}.name"
  shorthand <- runProgram
    [ "type User = { id: Int, name: Str }" ]
    [ "let id = 9", "let name = \"pudu\"" ]
    "User{id, name}.id"
  recordPattern <- evaluateWith
    [ "type User = { id: Int, name: Str }" ]
    "match (User{id: 4, name: \"x\"}) { case User{id} => id * 2 }"
  tuple <- evaluate "(1, \"two\", true)"
  indexed <- evaluate "(10, 20, 30)[1]"
  let propagationProgram =
        [ "fn attempt(flag: Bool) -> Result[Int, Str] {"
        , "  if flag { Ok(1) } else { Err(\"stop\") }"
        , "}"
        , "fn run(flag: Bool) -> Result[Int, Str] {"
        , "  let value = attempt(flag)?"
        , "  Ok(value + 1)"
        , "}"
        ]
  propagation <- evaluateWith propagationProgram "run(true)"
  failure <- evaluateWith propagationProgram "run(false)"
  pure $ conjoin
    [ variant === "6"
    , qualified === "\"stop\""
    , counterexample "a record is built and read" (record === "\"ada\"")
    , counterexample "shorthand takes the binding of the same name" (shorthand === "9")
    , counterexample "a record pattern destructures it" (recordPattern === "8")
    , tuple === "(1, \"two\", true)"
    , indexed === "20"
    , counterexample "? unwraps a success" (propagation === "Ok(2)")
    , counterexample "? returns the failure from its function"
        (failure === "Err(\"stop\")")
    ]

testArrayConcat :: IO Property
testArrayConcat = do
  joined <- evaluate "[1, 2].concat([3, 4])"
  leftEmpty <- evaluate "[].concat([1])"
  rightEmpty <- evaluate "[1].concat([])"
  chained <- evaluate "[1].concat([2]).concat([3])"
  pure $ conjoin
    [ counterexample "two arrays join in order" (joined === "[1, 2, 3, 4]")
    , counterexample "an empty left side is the right side" (leftEmpty === "[1]")
    , counterexample "an empty right side is the left side" (rightEmpty === "[1]")
    , counterexample "joining chains" (chained === "[1, 2, 3]")
    ]

testKeyed :: IO Property
testKeyed = do
  ordered <- evaluate "mapOf([(\"b\", 2), (\"a\", 1)])"
  replaced <- evaluate "mapOf([(\"a\", 1), (\"a\", 2)])"
  built <- evaluate "mapOf([(\"a\", 1)]).insert(\"b\", 2)"
  sameEitherWay <- evaluate "mapOf([(\"a\", 1), (\"b\", 2)]) == mapOf([(\"b\", 2), (\"a\", 1)])"
  found <- evaluate "mapOf([(\"a\", 1)]).get(\"a\")"
  absent <- evaluate "mapOf([(\"a\", 1)]).get(\"z\")"
  merged <- evaluate "mapOf([(\"a\", 1)]).merge(mapOf([(\"a\", 9)]))"
  deduplicated <- evaluate "setOf([3, 1, 2, 1])"
  joined <- evaluate "setOf([1, 2]).union(setOf([2, 3]))"
  shared <- evaluate "setOf([1, 2, 3]).intersect(setOf([2, 3, 4]))"
  removed <- evaluate "setOf([1, 2, 3]).difference(setOf([2]))"
  unorderable <- codesOf "setOf([fn(x) => x])"
  literal <- evaluate "#{3, 1, 2, 1}"
  present <- evaluate "2 in #{1, 2, 3}"
  missing <- evaluate "4 in #{1, 2, 3}"
  literalUnorderable <- codesOf "#{fn(x) => x}"
  duplicatesEvaluate <- runProgram []
    [ "var order = 0"
    , "let values = #{{ order = order * 10 + 1\n1 }, { order = order * 10 + 2\n1 }}"
    ]
    "(order, values)"
  membershipOrder <- runProgram []
    [ "var order = 0"
    , "let found = { order = order * 10 + 1\n2 } in { order = order * 10 + 2\n#{2} }"
    ]
    "(order, found)"
  setLoop <- evaluateStatements
    [ "var total = 0"
    , "for member in setOf([1, 2, 3, 4]) { total = total + member }"
    , "total"
    ]
  mapLoop <- evaluateStatements
    [ "var total = 0"
    , "for pair in mapOf([(\"a\", 1), (\"b\", 2)]) { total = total + pair[1] }"
    , "total"
    ]
  pure $ conjoin
    [ counterexample "entries are kept in key order" (ordered === "{\"a\": 1, \"b\": 2}")
    , counterexample "a later pair replaces an earlier one" (replaced === "{\"a\": 2}")
    , counterexample "insertion keeps the order" (built === "{\"a\": 1, \"b\": 2}")
    , counterexample "two maps with the same entries are equal" (sameEitherWay === "true")
    , counterexample "a present key answers with its value" (found === "Some(1)")
    , counterexample "an absent key answers with nothing" (absent === "None")
    , counterexample "merging lets the second map win" (merged === "{\"a\": 9}")
    , counterexample "a set drops duplicates and orders" (deduplicated === "#{1, 2, 3}")
    , counterexample "union joins" (joined === "#{1, 2, 3}")
    , counterexample "intersection keeps what both have" (shared === "#{2, 3}")
    , counterexample "difference removes what the other has" (removed === "#{1, 3}")
    , counterexample "a value with no order cannot be a member" (unorderable === ["E7008"])
    , counterexample "literal members collapse into key order" (literal === "#{1, 2, 3}")
    , counterexample "membership finds a present value" (present === "true")
    , counterexample "membership rejects an absent value" (missing === "false")
    , counterexample "a literal keeps the existing order boundary"
        (literalUnorderable === ["E7008"])
    , counterexample "duplicate members still evaluate left to right"
        (duplicatesEvaluate === "(12, #{1})")
    , counterexample "membership evaluates candidate before Set"
        (membershipOrder === "(12, true)")
    , counterexample "a set is walked by for, as the grammar says" (setLoop === "10")
    , counterexample "a map is walked as key and value pairs" (mapLoop === "3")
    ]

testInterpolation :: IO Property
testInterpolation = do
  plain <- runProgram [] ["let name = \"ada\""] "\"hi {name}\""
  arithmetic <- evaluate "\"sum {1 + 2}\""
  collection <- evaluate "\"list {[1, 2]}\""
  character <- evaluate "\"char {'x'}\""
  several <- runProgram [] ["let a = 1", "let b = 2"] "\"{a} and {b}\""
  onlyHole <- runProgram [] ["let a = 7"] "\"{a}\""
  nestedCall <- evaluate "\"len {[1, 2, 3].length()}\""
  nestedString <- evaluate "\"in {\"q\"}\""
  escaped <- evaluate "\"a\\{b\\}c\""
  pure $ conjoin
    [ counterexample "text keeps its own content" (plain === "\"hi ada\"")
    , counterexample "an expression is evaluated" (arithmetic === "\"sum 3\"")
    , counterexample "a collection renders" (collection === "\"list [1, 2]\"")
    , counterexample "a character keeps its own content" (character === "\"char x\"")
    , counterexample "several holes render in order" (several === "\"1 and 2\"")
    , counterexample "a template may be only a hole" (onlyHole === "\"7\"")
    , counterexample "a hole may call a method" (nestedCall === "\"len 3\"")
    , counterexample "a hole may contain a string" (nestedString === "\"in q\"")
    , counterexample "an escaped brace is not a hole" (escaped === "\"a{b}c\"")
    ]

testTextMethods :: IO Property
testTextMethods = do
  upper <- evaluate "\"aB\".toUpper()"
  trimmed <- evaluate "\"  x \".trim()"
  split <- evaluate "\"a,b\".split(\",\")"
  chars <- evaluate "\"hi\".chars()"
  charAt <- evaluate "\"héllo\".charAt(1)"
  scalarLength <- evaluate "\"héllo\".length()"
  sliced <- evaluate "\"hello\".slice(1, 3)"
  clamped <- evaluate "\"hi\".slice(0, 99)"
  absent <- evaluate "\"hello\".indexOf(\"zz\")"
  replaced <- evaluate "\"banana\".replace(\"a\", \"o\")"
  reversed <- evaluate "\"abc\".reverse()"
  unchanged <- runProgram [] ["var name = \"a\"", "name.toUpper()"] "name"
  outOfRange <- codesOf "\"hi\".charAt(9)"
  negativeRepeat <- codesOf "\"hi\".repeat(-1)"
  pure $ conjoin
    [ counterexample "case folds" (upper === "\"AB\"")
    , counterexample "whitespace is stripped" (trimmed === "\"x\"")
    , counterexample "split yields the fields" (split === "[\"a\", \"b\"]")
    , counterexample "chars yields characters" (chars === "['h', 'i']")
    , counterexample "indices count scalars, not bytes" (charAt === "'\233'")
    , counterexample "length counts scalars, not bytes" (scalarLength === "5")
    , counterexample "a slice takes the range" (sliced === "\"el\"")
    , counterexample "a slice past the end is the rest" (clamped === "\"hi\"")
    , counterexample "an absent needle answers -1" (absent === "-1")
    , counterexample "replace changes every occurrence" (replaced === "\"bonono\"")
    , counterexample "reverse reverses" (reversed === "\"cba\"")
    , counterexample "the receiver is unchanged" (unchanged === "\"a\"")
    , counterexample "an index outside the text is E7004" (outOfRange === ["E7004"])
    , counterexample "a negative repeat is E7004" (negativeRepeat === ["E7004"])
    ]
