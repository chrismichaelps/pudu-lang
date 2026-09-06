{-| @Test.Type.Check.DataSpec — records, variants, tuples, maps, and sets type checking -}
module Pudu.Type.Check.DataSpec
  ( colorProgram
  , dataProperties
  , testDiscardedResult
  , testKeyedTypes
  , testNamedVariants
  , testPreludeData
  , testRecords
  , testTupleIndex
  , testVariants
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..))
import Pudu.Diagnostic
  ( diagnosticHelp
  , diagnosticMessage
  , diagnosticSpan
  )
import Pudu.Source (spanEnd, spanStart, unOffset)
import Pudu.Type.Check.Common
  ( codes
  , codesOf
  , codesOfExpression
  , compile
  , typeOf
  )
import Test.QuickCheck (Property, conjoin, counterexample, (===))

dataProperties :: [(String, IO Property)]
dataProperties =
  [ ("maps and sets are typed by what they hold", testKeyedTypes)
  , ("a tuple is indexed by a literal position", testTupleIndex)
  , ("a discarded collection result is reported", testDiscardedResult)
  , ("records check fields on construction and access", testRecords)
  , ("sum constructors and patterns type their payloads", testVariants)
  , ("wired-in Option and Result carry their constructors", testPreludeData)
  , ("a variant may name its payload", testNamedVariants)
  ]

colorProgram :: [Text]
colorProgram = ["module M", "type Color = | Red | Green | Blue"]

testTupleIndex :: IO Property
testTupleIndex = do
  firstMember <- typeOf "(1, \"x\")[0]"
  secondMember <- typeOf "(1, \"x\")[1]"
  computed <- codes
    ["module M", "fn run() -> Int {", "  var index = 1", "  (1, \"x\")[index]", "}"]
  beyond <- codesOfExpression "(1, \"x\")[5]"
  negative <- codesOfExpression "(1, \"x\")[-1]"
  arrayIndex <- typeOf "[1, 2][1]"
  pure $ conjoin
    [ counterexample "the first member has the first type" (firstMember === "Int")
    , counterexample "the second member has the second type" (secondMember === "Str")
    , counterexample "a computed position is E3027" (computed === ["E3027"])
    , counterexample "a position beyond the tuple is E3027" (beyond === ["E3027"])
    , counterexample "a negative position is E3027" (negative === ["E3027"])
    , counterexample "an array is still indexed by any expression" (arrayIndex === "Int")
    ]

testKeyedTypes :: IO Property
testKeyedTypes = do
  mapType <- typeOf "mapOf([(\"a\", 1)])"
  setType <- typeOf "setOf([1, 2])"
  lookupType <- typeOf "mapOf([(\"a\", 1)]).get(\"a\")"
  keysType <- typeOf "mapOf([(\"a\", 1)]).keys()"
  entriesType <- typeOf "mapOf([(\"a\", 1)]).entries()"
  membersType <- typeOf "setOf([1]).toArray()"
  unknownMap <- codesOfExpression "mapOf([(\"a\", 1)]).shout()"
  unknownSet <- codesOfExpression "setOf([1]).shout()"
  badKey <- codesOfExpression "mapOf([(\"a\", 1)]).get(1)"
  literalSetType <- typeOf "#{3, 1, 2}"
  membershipType <- typeOf "2 in #{1, 2, 3}"
  absentType <- typeOf "4 in #{1, 2, 3}"
  wrongMember <- codesOfExpression "1 in #{\"one\", \"two\"}"
  wrongContainer <- codesOfExpression "2 in [1, 2, 3]"
  contextualEmpty <- codes
    [ "module M"
    , "fn run() -> Set[Int] { #{} }"
    ]
  let ambiguousSource = Text.unlines
        [ "module M"
        , "fn run() -> Int {"
        , "  let values = #{}"
        , "  0"
        , "}"
        ]
  ambiguousResult <- compile ambiguousSource
  let ambiguousEmpty = codesOf ambiguousResult
      emptyStart = Text.length (fst (Text.breakOn "#{}" ambiguousSource))
      emptySetContract = case compileDiagnostics ambiguousResult of
        [diagnostic] -> conjoin
          [ diagnosticMessage diagnostic === "an empty Set needs an element type"
          , diagnosticHelp diagnostic
              === Just "annotate it, for example: let values: Set[Int] = #{}"
          , unOffset (spanStart (diagnosticSpan diagnostic)) === emptyStart
          , unOffset (spanEnd (diagnosticSpan diagnostic)) === emptyStart + 3
          ]
        diagnostics ->
          counterexample ("expected one E3037, found " <> show diagnostics) False
  nestedArray <- codes
    [ "module M"
    , "fn run() -> Int {"
    , "  let values = [#{}]"
    , "  0"
    , "}"
    ]
  nestedConstructor <- codes
    [ "module M"
    , "fn run() -> Int {"
    , "  let values = Some(#{})"
    , "  0"
    , "}"
    ]
  contextualNested <- codes
    [ "module M"
    , "fn take(values: Set[Int]) -> Int { values.size() }"
    , "fn run() -> Int { take(#{}) }"
    ]
  iteratedLiteral <- codes
    [ "module M"
    , "fn run() -> Int {"
    , "  var total = 0"
    , "  for value in #{1, 2, 3} { total = total + value }"
    , "  total"
    , "}"
    ]
  pure $ conjoin
    [ counterexample "a map is typed by key and value" (mapType === "Map[Str, Int]")
    , counterexample "a set is typed by its member" (setType === "Set[Int]")
    , counterexample "a lookup answers with an option" (lookupType === "Option[Int]")
    , counterexample "keys answer as an array" (keysType === "Array[Str]")
    , counterexample "entries answer as an array of pairs" (entriesType === "Array[(Str, Int)]")
    , counterexample "members answer as an array" (membersType === "Array[Int]")
    , counterexample "an unknown map method is E3005" (unknownMap === ["E3005"])
    , counterexample "an unknown set method is E3005" (unknownSet === ["E3005"])
    , counterexample "a key of the wrong type is E3001" (badKey === ["E3001"])
    , counterexample "a Set literal is typed by its members" (literalSetType === "Set[Int]")
    , counterexample "membership answers Bool" (membershipType === "Bool")
    , counterexample "membership type does not depend on presence" (absentType === "Bool")
    , counterexample "membership checks its candidate" (wrongMember === ["E3001"])
    , counterexample "membership is Set-only" (wrongContainer === ["E3001"])
    , counterexample "context determines an empty Set" (contextualEmpty === [])
    , counterexample "an unconstrained empty Set is E3037" (ambiguousEmpty === ["E3037"])
    , counterexample "E3037 explains and spans the literal exactly" emptySetContract
    , counterexample "a nested array cannot leak an empty Set variable" (nestedArray === ["E3037"])
    , counterexample "a constructor cannot leak an empty Set variable" (nestedConstructor === ["E3037"])
    , counterexample "a surrounding call may determine a nested empty Set" (contextualNested === [])
    , counterexample "for still consumes its own in separator" (iteratedLiteral === [])
    ]

testRecords :: IO Property
testRecords = do
  built <- codes
    [ "module M"
    , "type User = { id: Int, name: Str }"
    , "fn run() -> User { User{id: 1, name: \"a\"} }"
    ]
  wrongField <- codes
    [ "module M"
    , "type User = { id: Int, name: Str }"
    , "fn run() -> User { User{id: \"a\", name: \"a\"} }"
    ]
  missingField <- codes
    [ "module M"
    , "type User = { id: Int, name: Str }"
    , "fn run() -> User { User{id: 1} }"
    ]
  unknownField <- codes
    [ "module M"
    , "type User = { id: Int, name: Str }"
    , "fn run() -> User { User{id: 1, name: \"a\", extra: 2} }"
    ]
  access <- codes
    [ "module M"
    , "type User = { id: Int, name: Str }"
    , "fn run(user: User) -> Str { user.name }"
    ]
  unknownAccess <- codes
    [ "module M"
    , "type User = { id: Int, name: Str }"
    , "fn run(user: User) -> Str { user.missing }"
    ]
  pure $ conjoin
    [ built === []
    , wrongField === ["E3001"]
    , missingField === ["E3008"]
    , unknownField === ["E3005"]
    , access === []
    , unknownAccess === ["E3005"]
    ]

testVariants :: IO Property
testVariants = do
  constructed <- codes
    [ "module M"
    , "type Outcome = | Ok(Int) | Err(Str)"
    , "fn run() -> Outcome { Ok(1) }"
    ]
  wrongPayload <- codes
    [ "module M"
    , "type Outcome = | Ok(Int) | Err(Str)"
    , "fn run() -> Outcome { Ok(\"a\") }"
    ]
  matched <- codes
    [ "module M"
    , "type Outcome = | Ok(Int) | Err(Str)"
    , "fn run(value: Outcome) -> Int {"
    , "  match value {"
    , "    case Ok(inner) => inner"
    , "    case Err(_) => 0"
    , "  }"
    , "}"
    ]
  wrongArm <- codes
    [ "module M"
    , "type Outcome = | Ok(Int) | Err(Str)"
    , "fn run(value: Outcome) -> Int {"
    , "  match value {"
    , "    case Ok(inner) => inner"
    , "    case Err(reason) => reason"
    , "  }"
    , "}"
    ]
  pure $ conjoin
    [ constructed === []
    , wrongPayload === ["E3001"]
    , matched === []
    , counterexample "arms unify to one type" (wrongArm === ["E3001"])
    ]

testNamedVariants :: IO Property
testNamedVariants = do
  let shape =
        [ "module M"
        , "type Shape = Circle{ radius: Int } | Rect{ width: Int, height: Int } | Point"
        ]
  built <- codes (shape <> ["fn run() -> Shape { Circle{radius: 2} }"])
  matched <- codes (shape <>
    [ "fn run(s: Shape) -> Int {"
    , "  match s {"
    , "    case Circle{radius} => radius"
    , "    case Rect{width, height} => width * height"
    , "    case Point => 0"
    , "  }"
    , "}"
    ])
  missingField <- codes (shape <> ["fn run() -> Shape { Rect{width: 3} }"])
  unknownField <- codes (shape <> ["fn run() -> Shape { Circle{diameter: 2} }"])
  wrongFieldType <- codes (shape <> ["fn run() -> Shape { Circle{radius: \"big\"} }"])
  positional <- codes (shape <> ["fn run() -> Shape { Point{x: 1} }"])
  incomplete <- codes (shape <>
    [ "fn run(s: Shape) -> Int {"
    , "  match s { case Circle{radius} => radius case Point => 0 }"
    , "}"
    ])
  testedField <- codes (shape <>
    [ "fn run(s: Shape) -> Int {"
    , "  match s {"
    , "    case Circle{radius: 0} => 0"
    , "    case Rect{width, height} => width * height"
    , "    case Point => 0"
    , "  }"
    , "}"
    ])
  repeated <- codes (shape <>
    [ "fn run(s: Shape) -> Int {"
    , "  match s {"
    , "    case Circle{radius} => radius"
    , "    case Circle{radius} => radius"
    , "    case Rect{width, height} => width * height"
    , "    case Point => 0"
    , "  }"
    , "}"
    ])
  plainRecord <- codes
    [ "module M"
    , "type Boxed = { value: Int }"
    , "fn run(b: Boxed) -> Int { match b { case Boxed{value} => value } }"
    ]
  generic <- codes
    [ "module M"
    , "type Chain[T] = Node{ item: T } | End"
    , "fn run() -> Int {"
    , "  let chain = Node{item: 7}"
    , "  match chain { case Node{item} => item case End => 0 }"
    , "}"
    ]
  calledBare <- codes (shape <> ["fn run() -> Shape { Circle(5) }"])
  calledQualified <- codes (shape <> ["fn run() -> Shape { Shape.Circle(5) }"])
  unapplied <- codes (shape <>
    [ "fn run() -> Int {"
    , "  var make = Circle"
    , "  0"
    , "}"
    ])
  matchedByPosition <- codes (shape <>
    [ "fn run(s: Shape) -> Int {"
    , "  match s { case Circle(r) => r case Rect(w, h) => w * h case Point => 0 }"
    , "}"
    ])
  positionalVariant <- codes
    [ "module M"
    , "type Wrapped = Wrap(Int) | Empty"
    , "fn run() -> Wrapped { Wrap(5) }"
    ]
  pure $ conjoin
    [ counterexample "a named variant is constructed by its field names" (built === [])
    , counterexample "a named variant is matched by its field names" (matched === [])
    , counterexample "a missing field is reported" (missingField === ["E3008"])
    , counterexample "a field the variant does not declare is reported"
        (unknownField === ["E3008", "E3005"])
    , counterexample "a field is checked against its declared type"
        (wrongFieldType === ["E3001"])
    , counterexample "a variant with no names is not a record" (positional === ["E3007"])
    , counterexample "naming one variant leaves the others to cover"
        (incomplete === ["E5001"])
    , counterexample "a named field that tests does not cover its variant"
        (testedField === ["E5001"])
    , counterexample "a variant named twice is unreachable the second time"
        (repeated === ["W5001"])
    , counterexample "a record type's own pattern covers it" (plainRecord === [])
    , counterexample "a generic variant is instantiated where it is written"
        (generic === [])
    , counterexample "a named variant is not called" (calledBare === ["E3034"])
    , counterexample "a named variant is not called through its type"
        (calledQualified === ["E3034"])
    , counterexample "a named variant is not a value" (unapplied === ["E3034"])
    , counterexample "a named variant is not matched by position"
        (matchedByPosition === ["E3034", "E3034"])
    , counterexample "a variant that names nothing is still a constructor"
        (positionalVariant === [])
    ]

testPreludeData :: IO Property
testPreludeData = do
  option <- typeOf "Some(1)"
  none <- codesOfExpression "None"
  result <- typeOf "Ok(1)"
  wrongPayload <- codes
    [ "module M"
    , "fn run() -> Option[Int] { Some(\"text\") }"
    ]
  generic <- codes
    [ "module M"
    , "type Wrapper[T] = | Wrap(T) | Empty"
    , "fn run() -> Int {"
    , "  match Wrap(1) {"
    , "    case Wrap(value) => value"
    , "    case Empty => 0"
    , "  }"
    , "}"
    ]
  shadowed <- codes
    [ "module M"
    , "type Mine = | Ok(Str) | Err(Str)"
    , "fn run() -> Mine { Ok(\"text\") }"
    ]
  pure $ conjoin
    [ counterexample "Some builds an Option" (option === "Option[Int]")
    , counterexample "None needs no declaration" (none === [])
    , counterexample "Ok builds a Result" (Text.isPrefixOf "Result[Int" result === True)
    , counterexample "a constructor checks its payload" (wrongPayload === ["E3001"])
    , counterexample "a generic sum instantiates per use" (generic === [])
    , counterexample "a module may declare its own Ok" (shadowed === [])
    ]

testDiscardedResult :: IO Property
testDiscardedResult = do
  discarded <- codes
    ["module M", "fn run() -> Int {", "  var out = [1]", "  out.push(2)", "  5", "}"]
  assigned <- codes
    ["module M", "fn run() -> Int {", "  var out = [1]", "  out = out.push(2)", "  5", "}"]
  asked <- codes
    ["module M", "fn run() -> Int {", "  let out = [1]", "  out.contains(2)", "  5", "}"]
  reversedResult <- codes
    ["module M", "fn run() -> Int {", "  let out = [1]", "  out.reverse()", "  5", "}"]
  userMethod <- codes
    [ "module M"
    , "type Bag = { size: Int }"
    , "trait Fill { fn push(self: &Self, value: Int) -> Int }"
    , "impl Fill for Bag { fn push(self: &Self, value: Int) -> Int { value } }"
    , "fn run(bag: Bag) -> Int {"
    , "  bag.push(2)"
    , "  5"
    , "}"
    ]
  pure $ conjoin
    [ counterexample "a discarded push is W3002" (discarded === ["W3002"])
    , counterexample "assigning the result back is correct" (assigned === [])
    , counterexample "discarding an answer is not warned about" (asked === [])
    , counterexample "a discarded reverse is W3002" (reversedResult === ["W3002"])
    , counterexample "a user method of the same name is not warned about" (userMethod === [])
    ]
