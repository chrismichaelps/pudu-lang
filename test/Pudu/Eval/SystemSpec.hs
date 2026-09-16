{-| @Test.Eval.SystemSpec — evaluation of async tasks, scopes, unsafe regions, effects, and resource isolation -}
module Pudu.Eval.SystemSpec
  ( systemProperties
  , testAsync
  , testBorrowing
  , testClock
  , testEffects
  , testFailures
  , testResourceIsolation
  , testScopes
  , testUnsafeRegions
  ) where

import Control.Monad (when)
import qualified Data.Text as Text
import System.Directory (doesFileExist, getTemporaryDirectory, removeFile)
import System.IO (hClose, openTempFile)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

import Pudu.Eval.Common
  ( codesOf
  , codesOfConstant
  , escapeForSource
  , evaluate
  , evaluateAsyncWith
  , evaluateStatements
  , evaluateWith
  )
import Pudu.Eval.Concurrent
  ( cellNew
  , cellRead
  , closeConcurrentStore
  , newConcurrentStore
  )
import Pudu.Eval.Handle
  ( closeHandleStore
  , flushHandleAt
  , newHandleStore
  , openWriteHandle
  )
import Pudu.Eval.Io (IoOutcome (..))
import Pudu.Eval.Value (Value (UnitValue))

systemProperties :: [(String, IO Property)]
systemProperties =
  [ ("runtime failures report exact diagnostics", testFailures)
  , ("async calls stay cold until an async entry awaits them", testAsync)
  , ("borrowing and dereferencing read the same value", testBorrowing)
  , ("unsafe regions evaluate their block", testUnsafeRegions)
  , ("structured scopes join every task they start", testScopes)
  , ("effects answer with a result and are refused at compile time", testEffects)
  , ("calendar time and subprocesses answer with results", testClock)
  , ("runtime resource stores isolate concurrent evaluations", testResourceIsolation)
  ]

testResourceIsolation :: IO Property
testResourceIsolation = do
  temporary <- getTemporaryDirectory
  (firstPath, firstHostHandle) <- openTempFile temporary "pudu-runtime-first"
  hClose firstHostHandle
  (secondPath, secondHostHandle) <- openTempFile temporary "pudu-runtime-second"
  hClose secondHostHandle
  firstHandles <- newHandleStore
  secondHandles <- newHandleStore
  firstOpened <- openWriteHandle firstHandles firstPath
  secondOpened <- openWriteHandle secondHandles secondPath
  closeHandleStore firstHandles
  secondFlush <- case secondOpened of
    IoDone token -> flushHandleAt secondHandles token
    IoFailed problem -> pure (IoFailed problem)
  closeHandleStore secondHandles
  firstConcurrent <- newConcurrentStore
  secondConcurrent <- newConcurrentStore
  cellToken <- cellNew secondConcurrent UnitValue
  closeConcurrentStore firstConcurrent
  secondRead <- cellRead secondConcurrent cellToken
  closeConcurrentStore secondConcurrent
  mapM_ removeIfPresent [firstPath, secondPath]
  pure $ conjoin
    [ counterexample "each handle store begins its private token space at one"
        (conjoin [firstOpened === IoDone 1, secondOpened === IoDone 1])
    , counterexample "closing one handle store leaves the other writable"
        (secondFlush === IoDone ())
    , counterexample "closing one concurrency store leaves another store's cell reachable"
        (secondRead === IoDone UnitValue)
    ]
 where
  removeIfPresent path = do
    exists <- doesFileExist path
    when exists (removeFile path)

testScopes :: IO Property
testScopes = do
  awaitedChild <- evaluateAsyncWith
    [ "async fn work(n: Int) -> Result[Int, Str] { Ok(n * 2) }" ]
    "async with scope { let first = work(5).await\n Ok(first) }"
  unawaitedChild <- evaluateAsyncWith
    [ "async fn work(n: Int) -> Result[Int, Str] { Ok(n * 2) }" ]
    "async with scope { work(3)\n Ok(1) }"
  failingChild <- evaluateAsyncWith
    [ "async fn failing() -> Result[Int, Str] { Err(\"child failed\") }" ]
    "async with scope { failing()\n Ok(1) }"
  earliestFailure <- evaluateAsyncWith
    [ "async fn first() -> Result[Int, Str] { Err(\"first\") }"
    , "async fn second() -> Result[Int, Str] { Err(\"second\") }"
    ]
    "async with scope { first()\n second()\n Ok(1) }"
  pure $ conjoin
    [ counterexample "a scope yields its block's value" (awaitedChild === "10")
    , counterexample "an unawaited child still runs before the scope yields"
        (unawaitedChild === "1")
    , counterexample "a child's failure leaves the scope"
        (failingChild === "Err(\"child failed\")")
    , counterexample "the earliest failing child supplies the failure"
        (earliestFailure === "Err(\"first\")")
    ]

testUnsafeRegions :: IO Property
testUnsafeRegions = do
  blanket <- evaluateWith ["unsafe fn raw() -> Int { 42 }"] "unsafe { raw() }"
  named <- evaluateWith ["unsafe(raw) fn ptr() -> Int { 7 }"] "unsafe(raw) { ptr() * 2 }"
  nested <- evaluateWith
    [ "unsafe fn inner() -> Int { 3 }"
    , "unsafe fn outer() -> Int { inner() + 1 }"
    ]
    "unsafe { outer() }"
  pure $ conjoin
    [ counterexample "a region yields its block's value" (blanket === "42")
    , counterexample "a named region evaluates the same" (named === "14")
    , counterexample "an unsafe function may call another" (nested === "4")
    ]

testBorrowing :: IO Property
testBorrowing = do
  readThrough <- evaluateStatements
    [ "let value = 7"
    , "let borrowed = &value"
    , "*borrowed"
    ]
  fieldThrough <- evaluateWith
    [ "type User = { name: Str }" ]
    "(*(&User{name: \"ada\"})).name"
  selfDeref <- evaluateWith
    [ "type User = { name: Str }"
    , "trait Clone {"
    , "  fn duplicate(self: &Self) -> Self"
    , "}"
    , "impl Clone for User {"
    , "  fn duplicate(self: &Self) -> Self { *self }"
    , "}"
    ]
    "User{name: \"ada\"}.duplicate().name"
  pure $ conjoin
    [ counterexample "a dereference reads the borrowed value" (readThrough === "7")
    , counterexample "a field is reached through a dereference" (fieldThrough === "\"ada\"")
    , counterexample "&Self dereferences to the receiver" (selfDeref === "\"ada\"")
    ]

testFailures :: IO Property
testFailures = do
  divisor <- codesOf "1 / 0"
  modulo <- codesOf "1 % 0"
  outOfRange <- codesOf "[1, 2][5]"
  mismatch <- codesOf "1 + true"
  noArm <- codesOf "match 9 { case 1 => 1 }"
  panic <- codesOf "panic(\"boom\")"
  excessiveDerivationRounds <-
    codesOf "deriveKey(\"p\".toBytes(), \"s\".toBytes(), 10000001, 32)"
  excessiveDerivedBytes <-
    codesOf "deriveKey(\"p\".toBytes(), \"s\".toBytes(), 1, 1048577)"
  pure $ conjoin
    [ divisor === ["E7004"]
    , modulo === ["E7004"]
    , outOfRange === ["E7004"]
    , counterexample "typing rejects a mixed operand before evaluation"
        (mismatch === ["E3001"])
    , counterexample "an unmatched value is rejected before it can be evaluated"
        (noArm === ["E5001"])
    , counterexample "panic stops evaluation with E7007"
        (panic === ["E7007"])
    , counterexample "PBKDF2 bounds hostile iteration counts before host conversion"
        (excessiveDerivationRounds === ["E7004"])
    , counterexample "PBKDF2 bounds hostile allocation counts before host conversion"
        (excessiveDerivedBytes === ["E7004"])
    ]

testAsync :: IO Property
testAsync = do
  cold <- evaluateWith ["async fn fetch() -> Int { 42 }"] "fetch()"
  awaited <- evaluateAsyncWith ["async fn fetch() -> Int { 42 }"] "Ok(fetch().await)"
  success <- evaluateAsyncWith
    ["async fn fetch() -> Result[Int, Str] { Ok(42) }"]
    "Ok(fetch().await)"
  failure <- evaluateAsyncWith
    ["async fn fetch() -> Result[Int, Str] { Err(\"stop\") }"]
    "Ok(fetch().await)"
  forward <- evaluateAsyncWith
    [ "async fn run() -> Int { fetch().await }"
    , "async fn fetch() -> Int { 42 }"
    ]
    "Ok(run().await)"
  pure $ conjoin
    [ counterexample "calling async does not run its body" (cold === "<task fetch>")
    , counterexample "await starts a non-failing task" (awaited === "42")
    , counterexample "await unwraps task success" (success === "42")
    , counterexample "await propagates task failure" (failure === "Err(\"stop\")")
    , counterexample "forward async calls run from collected declarations" (forward === "42")
    ]

testClock :: IO Property
testClock = do
  rendered <- evaluate "formatTime(\"%Y-%m-%d\", 1700000000000, \"utc\")"
  parsed <- evaluate "parseTime(\"%Y-%m-%d\", \"2023-11-14\")"
  malformed <- evaluate "parseTime(\"%Y-%m-%d\", \"not a date\")"
  ticking <- evaluate "now() > 1600000000000"
  ran <- evaluate "runProgram(\"echo\", [\"hi\"], \"\")"
  failed <- evaluate "runProgram(\"sh\", [\"-c\", \"exit 7\"], \"\")"
  missing <- evaluate "runProgram(\"pudu-no-such-program-4c3b\", [], \"\")"
  atCompileTime <- codesOfConstant "now() > 0"
  pure $ conjoin
    [ counterexample "an instant renders with a pattern" (rendered === "Ok(\"2023-11-14\")")
    , counterexample "text reads back as an instant" (parsed === "Ok(1699920000000)")
    , counterexample "text that does not fit reports the pattern"
        (property (Text.isPrefixOf "Err(" malformed))
    , counterexample "the system clock is past 2020" (ticking === "true")
    , counterexample "a program's output is collected" (ran === "Ok((0, \"hi\\n\", \"\"))")
    , counterexample "a non-zero status is an answer, not a failure"
        (property (Text.isPrefixOf "Ok((7," failed))
    , counterexample "a program that cannot be run is a failure"
        (property (Text.isPrefixOf "Err(" missing))
    , counterexample "a constant may not read the clock" (atCompileTime === ["E7009"])
    ]

testEffects :: IO Property
testEffects = do
  directory <- getTemporaryDirectory
  (path, handle) <- openTempFile directory "pudu-effect-test.txt"
  hClose handle
  let quoted = Text.pack (escapeForSource path)
      absentPath = quoted <> ".absent"
  written <- evaluate ("writeFile(\"" <> quoted <> "\", \"x\")")
  readBack <- evaluate ("readFile(\"" <> quoted <> "\")")
  missing <- evaluate ("readFile(\"" <> absentPath <> "\")")
  present <- evaluate ("fileExists(\"" <> quoted <> "\")")
  absent <- evaluate ("fileExists(\"" <> absentPath <> "\")")
  removed <- evaluate ("removeFile(\"" <> quoted <> "\")")
  ticking <- evaluate "clock() >= 0"
  atCompileTime <- codesOfConstant ("fileExists(\"" <> quoted <> "\")")
  stillThere <- doesFileExist path
  when stillThere (removeFile path)
  pure $ conjoin
    [ counterexample "writing answers with success" (written === "Ok(())")
    , counterexample "reading answers with the contents" (readBack === "Ok(\"x\")")
    , counterexample "a missing file is a failure, not a crash"
        (property (Text.isPrefixOf "Err(" missing))
    , counterexample "a present path is reported" (present === "true")
    , counterexample "an absent path is reported" (absent === "false")
    , counterexample "removing answers with success" (removed === "Ok(())")
    , counterexample "the clock moves forward" (ticking === "true")
    , counterexample "a constant may not reach the world" (atCompileTime === ["E7009"])
    ]
