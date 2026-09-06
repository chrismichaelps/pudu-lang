{-| @Test.Type.Check.SystemSpec — references, marker traits, unsafe regions, and concurrency -}
module Pudu.Type.Check.SystemSpec
  ( systemProperties
  , testDereference
  , testMarkers
  , testUnsafe
  , testComptime
  , testAsync
  , testScopes
  , testRecordedTypes
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Test.QuickCheck ((===), Property, conjoin, counterexample)

import Pudu.Type.Check.Common (codes, compile, diagnosticContract, typeOfIn)

systemProperties :: [(String, IO Property)]
systemProperties =
  [ ("async calls normalize task channels and await them", testAsync)
  , ("references are dereferenced explicitly in both directions", testDereference)
  , ("types implement Copy, Send, and Sync by structural rules", testMarkers)
  , ("unsafe regions grant named capabilities and contain their calls", testUnsafe)
  , ("comptime code cannot reach runtime declarations", testComptime)
  , ("a structured scope requires an async function", testScopes)
  , ("expression types are recorded for tooling", testRecordedTypes)
  ]

userProgram :: [Text]
userProgram = ["module M", "type User = { name: Str }"]

testDereference :: IO Property
testDereference = do
  readThrough <- codes (userProgram <>
    [ "fn run(user: User) -> User {"
    , "  let borrowed = &user"
    , "  *borrowed"
    , "}"
    ])
  fieldThroughBorrow <- codes (userProgram <>
    [ "fn run(user: User) -> Str {"
    , "  let borrowed = &user"
    , "  (*borrowed).name"
    , "}"
    ])
  selfDeref <- codes (userProgram <>
    [ "trait Clone {"
    , "  fn duplicate(self: &Self) -> Self"
    , "}"
    , "impl Clone for User {"
    , "  fn duplicate(self: &Self) -> Self { *self }"
    , "}"
    ])
  borrowWhereValue <- codes (userProgram <>
    [ "fn takes(user: User) -> User { user }"
    , "fn run(user: User) -> User { takes(&user) }"
    ])
  nonReference <- codes (userProgram <> ["fn run(user: User) -> User { *user }"])
  mutableBorrow <- codes (userProgram <>
    [ "fn run(user: User) -> User {"
    , "  let borrowed = &mut user"
    , "  *borrowed"
    , "}"
    ])
  derefType <- typeOfIn
    (drop 1 userProgram <>
      [ "fn run(user: User) -> User {"
      , "  let borrowed = &user"
      , "  *borrowed"
      , "}"
      ])
    "*borrowed"
  pure $ conjoin
    [ counterexample "a borrow is read with *" (readThrough === [])
    , counterexample "a field is reached through a dereference" (fieldThroughBorrow === [])
    , counterexample "&Self dereferences to Self" (selfDeref === [])
    , counterexample "no implicit conversion from a borrow" (borrowWhereValue === ["E3001"])
    , counterexample "a non-reference cannot be dereferenced" (nonReference === ["E3020"])
    , counterexample "an exclusive borrow dereferences too" (mutableBorrow === [])
    , counterexample "the dereference has the referent's type" (derefType === "User")
    ]

markerProgram :: [Text]
markerProgram =
  [ "module M"
  , "type Point = { x: Int, y: Int }"
  , "type Handle = { label: Str }"
  , "type Choice = | Yes | No | Amount(Int)"
  , "fn copies[T: Copy](value: T) -> T { value }"
  , "fn sends[T: Send](value: T) -> T { value }"
  , "fn shares[T: Sync](value: T) -> T { value }"
  ]

testMarkers :: IO Property
testMarkers = do
  scalars <- codes (markerProgram <>
    [ "fn run() -> Int { copies(1) }"
    , "fn float() -> Float64 { copies(1.5) }"
    , "fn flag() -> Bool { copies(true) }"
    , "fn letter() -> Char { copies('a') }"
    ])
  aggregates <- codes (markerProgram <>
    [ "fn pair() -> (Int, Bool) { copies((1, true)) }"
    , "fn record() -> Point { copies(Point{x: 1, y: 2}) }"
    , "fn variant() -> Choice { copies(Amount(3)) }"
    ])
  sharedBorrow <- codes (markerProgram <> ["fn run(p: Point) -> &Point { copies(&p) }"])
  ownedText <- codes (markerProgram <> ["fn run() -> Str { copies(\"owned\") }"])
  owningRecord <- codes (markerProgram <> ["fn run(h: Handle) -> Handle { copies(h) }"])
  exclusiveBorrow <- codes (markerProgram <> ["fn run(p: Point) -> &mut Point { copies(&mut p) }"])
  collection <- codes (markerProgram <> ["fn run(xs: Array[Int]) -> Array[Int] { copies(xs) }"])
  sendableText <- codes (markerProgram <> ["fn run() -> Str { sends(\"text\") }"])
  sharedText <- codes (markerProgram <> ["fn run() -> Str { shares(\"text\") }"])
  sendableCollection <- codes (markerProgram <>
    ["fn run(xs: Array[Int]) -> Array[Int] { sends(xs) }"])
  userCopyImpl <- codes
    [ "module M"
    , "type Point = { x: Int }"
    , "trait Copy { fn dummy(self: &Self) -> Int }"
    , "impl Copy for Point {"
    , "  fn dummy(self: &Self) -> Int { self.x }"
    , "}"
    ]
  pure $ conjoin
    [ counterexample "every scalar copies" (scalars === [])
    , counterexample "an aggregate of copyable components copies" (aggregates === [])
    , counterexample "a shared borrow copies" (sharedBorrow === [])
    , counterexample "owned text does not copy" (ownedText === ["E3012"])
    , counterexample "a record holding text does not copy" (owningRecord === ["E3012"])
    , counterexample "an exclusive borrow never copies" (exclusiveBorrow === ["E3012"])
    , counterexample "a growable collection does not copy" (collection === ["E3012"])
    , counterexample "text crosses into a task" (sendableText === [])
    , counterexample "text is shareable" (sharedText === [])
    , counterexample "a collection of sendable elements is sendable"
        (sendableCollection === [])
    , counterexample "Copy cannot be implemented by hand" (userCopyImpl === ["E3021"])
    ]

unsafeProgram :: [Text]
unsafeProgram =
  [ "module M"
  , "unsafe fn blanket() -> Int { 42 }"
  , "unsafe(raw) fn rawOnly() -> Int { 7 }"
  ]

testUnsafe :: IO Property
testUnsafe = do
  declaring <- codes unsafeProgram
  fromSafe <- codes (unsafeProgram <> ["fn run() -> Int { blanket() }"])
  wrapped <- codes (unsafeProgram <> ["fn run() -> Int { unsafe { blanket() } }"])
  precise <- codes (unsafeProgram <> ["fn run() -> Int { unsafe(raw) { rawOnly() } }"])
  wrongCapability <- codes (unsafeProgram <> ["fn run() -> Int { unsafe(null) { rawOnly() } }"])
  blanketGrantsAll <- codes (unsafeProgram <> ["fn run() -> Int { unsafe { rawOnly() } }"])
  fromUnsafeFunction <- codes (unsafeProgram <> ["unsafe fn run() -> Int { blanket() }"])
  unusedRegion <- codes (unsafeProgram <> ["fn run() -> Int { unsafe { 1 } }"])
  unusedCapability <- codes (unsafeProgram <>
    ["fn run() -> Int { unsafe(raw, null) { rawOnly() } }"])
  regionType <- typeOfIn (drop 1 unsafeProgram <> ["fn run() -> Int { unsafe { blanket() } }"])
    "unsafe { blanket() }"
  nullOutside <- codes ["module M", "fn run() -> Int { null }"]
  nullInside <- codes ["module M", "fn run() -> Int { unsafe(null) { null } }"]
  unknownCapability <- codes (unsafeProgram <>
    ["fn run() -> Int { unsafe(bogus) { blanket() } }"])
  pure $ conjoin
    [ counterexample "declaring is clean" (declaring === [])
    , counterexample "a safe caller is rejected" (fromSafe === ["E3023"])
    , counterexample "a blanket region admits a blanket call" (wrapped === [])
    , counterexample "a named region admits the call it grants" (precise === [])
    , counterexample "a region without the capability is rejected"
        (wrongCapability === ["W3001", "E3023"])
    , counterexample "a blanket region grants every capability" (blanketGrantsAll === [])
    , counterexample "an unsafe function's body is a region" (fromUnsafeFunction === [])
    , counterexample "a region nothing used is reported" (unusedRegion === ["W3001"])
    , counterexample "an unused capability is reported" (unusedCapability === ["W3001"])
    , counterexample "a region has the type of its block" (regionType === "Int")
    , counterexample "null needs its capability" (nullOutside === ["E3024"])
    , counterexample "null still has no type inside" (nullInside === ["E3024"])
    , counterexample "the capability vocabulary is closed"
        (unknownCapability === ["E1044"])
    ]

comptimeProgram :: [Text]
comptimeProgram =
  [ "module M"
  , "comptime fn double(n: Int) -> Int { n * 2 }"
  , "fn runtime(n: Int) -> Int { n + 1 }"
  ]

testComptime :: IO Property
testComptime = do
  declaring <- codes comptimeProgram
  chained <- codes (comptimeProgram <>
    ["comptime fn quadruple(n: Int) -> Int { double(double(n)) }"])
  reachesRuntime <- codes (comptimeProgram <>
    ["comptime fn impure(n: Int) -> Int { runtime(n) }"])
  asyncComptime <- codes (comptimeProgram <>
    ["comptime async fn spawned() -> Int { 1 }"])
  unsafeComptime <- codes (comptimeProgram <>
    ["comptime unsafe fn unchecked() -> Int { 1 }"])
  calledAtRuntime <- codes (comptimeProgram <> ["fn run() -> Int { double(5) }"])
  constantFolds <- codes (comptimeProgram <> ["const VALUE: Int = double(21)"])
  constantFails <- codes ["module M", "const VALUE: Int = 1 / 0"]
  constantBudget <- codes
    [ "module M"
    , "fn spin() -> Int {"
    , "  var total = 0"
    , "  loop { total = total + 1 }"
    , "  total"
    , "}"
    , "const VALUE: Int = spin()"
    ]
  builtinsAllowed <- codes (comptimeProgram <>
    ["comptime fn wrap(n: Int) -> Option[Int] { Some(n) }"])
  pure $ conjoin
    [ counterexample "declaring is clean" (declaring === [])
    , counterexample "compile-time code may call compile-time code" (chained === [])
    , counterexample "it may not call a runtime function" (reachesRuntime === ["E3025"])
    , counterexample "it may not be async" (asyncComptime === ["E3025"])
    , counterexample "it may not be unsafe" (unsafeComptime === ["E3025"])
    , counterexample "runtime code may still call it" (calledAtRuntime === [])
    , counterexample "a constant folds at compile time" (constantFolds === [])
    , counterexample "a failing constant fails the compile" (constantFails === ["E7004"])
    , counterexample "an unbounded constant exhausts the budget"
        (constantBudget === ["E7002"])
    , counterexample "wired-in constructors stay reachable" (builtinsAllowed === [])
    ]

testAsync :: IO Property
testAsync = do
  task <- typeOfIn
    [ "async fn fetch() -> Int { 42 }"
    , "fn run() { fetch() }"
    ] "fetch()"
  failingTask <- typeOfIn
    [ "async fn fetch() -> Result[Int, Str] { Ok(42) }"
    , "fn run() { fetch() }"
    ] "fetch()"
  forwardTask <- typeOfIn
    [ "fn run() { (fetch()) }"
    , "async fn fetch() -> Result[Int, Str] { Ok(42) }"
    ] "(fetch())"
  awaited <- typeOfIn
    [ "async fn fetch() -> Int { 42 }"
    , "async fn run() -> Int { fetch().await }"
    ] "fetch().await"
  propagated <- codes
    [ "module M"
    , "async fn fetch() -> Result[Int, Str] { Ok(42) }"
    , "async fn run() -> Result[Int, Str] {"
    , "  let value = fetch().await"
    , "  Ok(value)"
    , "}"
    ]
  syncAwait <- codes
    [ "module M"
    , "async fn fetch() -> Int { 42 }"
    , "fn run() -> Int { fetch().await }"
    ]
  nonTask <- codes
    [ "module M"
    , "async fn run() -> Int { (1).await }"
    ]
  missingCarrier <- codes
    [ "module M"
    , "async fn fetch() -> Result[Int, Str] { Ok(42) }"
    , "async fn run() -> Int { fetch().await }"
    ]
  wrongFailure <- codes
    [ "module M"
    , "async fn fetch() -> Result[Int, Str] { Ok(42) }"
    , "async fn run() -> Result[Int, Bool] {"
    , "  let value = fetch().await"
    , "  Ok(value)"
    , "}"
    ]
  let missingReturnSource = Text.unlines
        [ "module M"
        , "async fn fetch() { 42 }"
        ]
      missingParameterSource = Text.unlines
        [ "module M"
        , "async fn fetch(value) -> Int { value }"
        ]
      syncAwaitSource = Text.unlines
        [ "module M"
        , "async fn fetch() -> Int { 42 }"
        , "fn run() -> Int { fetch().await }"
        ]
      nonTaskSource = Text.unlines
        [ "module M"
        , "async fn run() -> Int { (1).await }"
        ]
  missingReturn <- compile missingReturnSource
  missingParameter <- compile missingParameterSource
  syncAwaitDiagnostic <- compile syncAwaitSource
  nonTaskDiagnostic <- compile nonTaskSource
  pure $ conjoin
    [ counterexample "a non-failing async call is a Task" (task === "Task[Int, Never]")
    , counterexample "Result supplies the task failure channel" (failingTask === "Task[Int, Str]")
    , counterexample "forward calls use the declared task channels" (forwardTask === "Task[Int, Str]")
    , counterexample "await yields the task success channel" (awaited === "Int")
    , counterexample "a compatible async Result propagates failure" (propagated === [])
    , counterexample "await is confined to async functions" (syncAwait === ["E3016"])
    , counterexample "await accepts only Task" (nonTask === ["E3017"])
    , counterexample "failing await needs a Result carrier" (missingCarrier === ["E3011"])
    , counterexample "await failure types must agree" (wrongFailure === ["E3001"])
    , diagnosticContract missingReturnSource "fetch" "E3010"
        "async function fetch needs a return type"
        (Just "annotate the return type so callers can form Task[S, E] without inspecting the body")
        missingReturn
    , diagnosticContract missingParameterSource "value)" "E3010"
        "async parameter value needs a type"
        (Just "annotate every parameter of an async function so calls do not determine its contract")
        missingParameter
    , diagnosticContract syncAwaitSource "fetch().await" "E3016"
        ".await is only legal inside async fn"
        (Just "move the await into an async function, or return the task")
        syncAwaitDiagnostic
    , diagnosticContract nonTaskSource "(1).await" "E3017"
        ".await needs a Task, found Int"
        (Just "await an async function call or another Task value")
        nonTaskDiagnostic
    ]

testScopes :: IO Property
testScopes = do
  inAsync <- codes
    [ "module M"
    , "async fn run() -> Result[Int, Str] { async with scope { Ok(1) } }"
    ]
  inSync <- codes ["module M", "fn run() -> Int { async with scope { 1 } }"]
  scopeType <- typeOfIn
    [ "async fn run() -> Result[Int, Str] { async with scope { Ok(1) } }" ]
    "async with scope { Ok(1) }"
  pure $ conjoin
    [ counterexample "an async function may open a scope" (inAsync === [])
    , counterexample "a synchronous one may not" (inSync === ["E3026"])
    , counterexample "a scope has its block's type"
        (Text.isPrefixOf "Result[Int" scopeType === True)
    ]

testRecordedTypes :: IO Property
testRecordedTypes = do
  recorded <- typeOfIn ["fn run() -> Bool {", "  1 < 2", "}"] "1 < 2"
  pure (recorded === "Bool")
