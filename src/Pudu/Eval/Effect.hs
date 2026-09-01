{-| @Program.Eval.Effect — performs the operations that reach outside -}
module Pudu.Eval.Effect
  ( callEffect
  , effectBuiltins
  ) where

import Data.Foldable (toList)
import Data.Maybe (fromMaybe)
import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic, Severity (Error), diagnostic, mkDiagnosticCode, withHelp)
import Pudu.Eval.Clock
import Pudu.Eval.Handle
  ( closeHandleAt
  , flushHandleAt
  , openAppendHandle
  , openReadHandle
  , openWriteHandle
  , readHandleChunk
  , writeHandleChunk
  )
import Pudu.Eval.Io
import Pudu.Eval.Env
  ( effectsAdmitted
  , performEffect
  , Evaluator (..)
  , abortAt
  )
import Pudu.Source (Span)
import Pudu.Eval.Render (renderValue)
import Pudu.Eval.Value
  ( Builtin (..)
  , builtinName
  , intOf
  , Value (..)
  )

{-| The built-ins that reach the world.

    They are listed once so the evaluator and the checker cannot disagree about
    which names exist, and so adding one is a single edit rather than three. -}
effectBuiltins :: [Builtin]
effectBuiltins =
  [ PrintBuiltin
  , PrintErrorBuiltin
  , PrintPartBuiltin
  , PrintErrorPartBuiltin
  , ReadLineBuiltin
  , ReadFileBuiltin
  , WriteFileBuiltin
  , AppendFileBuiltin
  , FileExistsBuiltin
  , RemoveFileBuiltin
  , ListDirectoryBuiltin
  , CreateDirectoryBuiltin
  , ArgumentsBuiltin
  , EnvironmentBuiltin
  , TemporaryDirectoryBuiltin
  , HomeDirectoryBuiltin
  , PathSeparatorsBuiltin
  , SearchSeparatorBuiltin
  , ExitBuiltin
  , ClockBuiltin
  , NowBuiltin
  , FormatTimeBuiltin
  , ParseTimeBuiltin
  , ZoneOffsetBuiltin
  , RunBuiltin
  , OpenReaderBuiltin
  , OpenWriterBuiltin
  , OpenAppenderBuiltin
  , ReadChunkBuiltin
  , WriteChunkBuiltin
  , FlushWriterBuiltin
  , CloseHandleBuiltin
  ]

{-| Perform one effect.

    Every one answers with a `Result` rather than failing the program: the
    language has no exceptions, and a runtime that unwound past a boundary the
    program cannot see would take away the only decision worth having. A missing
    file is an outcome a caller handles, not a crash.

    `exit` is the exception to that, and is the only one: a program that asked
    to stop has nothing left to decide. -}
callEffect :: Span -> Builtin -> [Value] -> Evaluator Value
callEffect spanValue builtin arguments = do
  admitted <- effectsAdmitted
  if not admitted
    then
      abortAt (Just spanValue) "E7009"
        (builtinName builtin <> " reaches outside the program")
        ( Just
            ( "a compile-time constant is folded while the compiler runs, so it "
                <> "cannot read, write, or ask the environment anything"
            )
        )
    else case (builtin, arguments) of
      (PrintBuiltin, [value]) -> effectUnit (writeStandardOutput (textOf value))
      (PrintErrorBuiltin, [value]) -> effectUnit (writeStandardError (textOf value))
      (PrintPartBuiltin, [value]) -> effectUnit (writeStandardOutputPart (textOf value))
      (PrintErrorPartBuiltin, [value]) -> effectUnit (writeStandardErrorPart (textOf value))
      (ReadLineBuiltin, []) -> do
        outcome <- lift refusal readStandardLine
        pure (resultOf (fmap optionalText outcome))
      (ReadFileBuiltin, [StrValue path]) ->
        resultOf . fmap StrValue <$> lift refusal (readTextFile (Text.unpack path))
      (WriteFileBuiltin, [StrValue path, value]) ->
        effectUnit (writeTextFile (Text.unpack path) (textOf value))
      (AppendFileBuiltin, [StrValue path, value]) ->
        effectUnit (appendTextFile (Text.unpack path) (textOf value))
      (FileExistsBuiltin, [StrValue path]) ->
        BoolValue <$> lift refusal (testFileExists (Text.unpack path))
      (RemoveFileBuiltin, [StrValue path]) -> effectUnit (removeFileAt (Text.unpack path))
      (ListDirectoryBuiltin, [StrValue path]) ->
        resultOf . fmap textArray <$> lift refusal (listDirectoryAt (Text.unpack path))
      (CreateDirectoryBuiltin, [StrValue path]) ->
        effectUnit (createDirectoryAt (Text.unpack path))
      {-| A handle is named by a token rather than held as a value, because a
          value is copied through evaluation and an open file is not: two
          copies of one file, each thinking it owns the position, would read
          the same bytes twice. The token means nothing outside the runtime,
          so a program cannot make one up. -}
      (OpenReaderBuiltin, [StrValue path]) ->
        resultOf . fmap intOf . fmap fromIntegral <$> lift refusal (openReadHandle (Text.unpack path))
      (OpenWriterBuiltin, [StrValue path]) ->
        resultOf . fmap intOf . fmap fromIntegral <$> lift refusal (openWriteHandle (Text.unpack path))
      (OpenAppenderBuiltin, [StrValue path]) ->
        resultOf . fmap intOf . fmap fromIntegral <$> lift refusal (openAppendHandle (Text.unpack path))
      {-| Nothing read means the input has ended, which is a different answer
          from an empty chunk: a reader that could not tell them apart would
          either stop early or never stop. -}
      (ReadChunkBuiltin, [IntValue _ token, IntValue _ count]) -> do
        outcome <- lift refusal (readHandleChunk (fromInteger token) (fromInteger count))
        pure (resultOf (fmap optionalBytes outcome))
      (WriteChunkBuiltin, [IntValue _ token, BytesValue chunk]) ->
        effectUnit (writeHandleChunk (fromInteger token) chunk)
      (FlushWriterBuiltin, [IntValue _ token]) ->
        effectUnit (flushHandleAt (fromInteger token))
      (CloseHandleBuiltin, [IntValue _ token]) ->
        effectUnit (closeHandleAt (fromInteger token))
      (ArgumentsBuiltin, []) -> textArray <$> lift refusal programArguments
      (EnvironmentBuiltin, []) -> pairArray <$> lift refusal environmentPairs
      (TemporaryDirectoryBuiltin, []) -> StrValue <$> lift refusal temporaryDirectoryPath
      (HomeDirectoryBuiltin, []) -> optionalText <$> lift refusal homeDirectoryPath
      (PathSeparatorsBuiltin, []) ->
        ArrayValue . Seq.fromList . map StrValue <$> lift refusal (pure pathSeparators)
      (SearchSeparatorBuiltin, []) -> StrValue <$> lift refusal (pure searchPathSeparatorText)
      (ClockBuiltin, []) -> intOf <$> lift refusal monotonicMilliseconds
      (NowBuiltin, []) -> intOf <$> lift refusal currentInstant
      (ZoneOffsetBuiltin, []) -> intOf <$> lift refusal timeZoneOffset
      (FormatTimeBuiltin, [StrValue pattern, IntValue _ milliseconds, StrValue zone]) -> do
        rendered <- lift refusal (formatInstant pattern milliseconds zone)
        pure (eitherOf (StrValue <$> rendered))
      (ParseTimeBuiltin, [StrValue pattern, StrValue text]) ->
        pure (eitherOf (intOf <$> parseInstant pattern text))
      (RunBuiltin, [StrValue program, ArrayValue given, StrValue standardInput]) -> do
        outcome <- lift refusal (runProcess (Text.unpack program) (textsOf given) standardInput)
        pure (eitherOf (processValue <$> outcome))
      (ExitBuiltin, [IntValue _ code]) -> do
        _ <- lift refusal (exitWith code)
        pure UnitValue
      _ ->
        abortAt (Just spanValue) "E7012"
          ("wrong arguments for " <> builtinName builtin) Nothing
 where
  refusal = effectRefusal spanValue builtin

  effectUnit action = resultOf . fmap (const UnitValue) <$> lift refusal action

  textOf value = case value of
    StrValue text -> text
    other -> renderValue other

  textArray = ArrayValue . Seq.fromList . map StrValue
  pairArray pairs =
    ArrayValue (Seq.fromList [TupleValue [StrValue name, StrValue value] | (name, value) <- pairs])
  optionalText found = case found of
    Just text -> VariantValue "Some" [StrValue text]
    Nothing -> VariantValue "None" []
  optionalBytes found = case found of
    Just chunk -> VariantValue "Some" [BytesValue chunk]
    Nothing -> VariantValue "None" []

{-| Run one effect behind the refusal that applies to it.

    A top-level binding rather than a local one so it stays polymorphic in what
    the effect produces; every effect here produces something different. -}
lift :: Diagnostic -> IO a -> Evaluator a
lift refusal action = performEffect refusal action

{-| An either as the language's own failure carrier. -}
eitherOf :: Either Text Value -> Value
eitherOf outcome = case outcome of
  Right value -> VariantValue "Ok" [value]
  Left message -> VariantValue "Err" [StrValue message]

{-| A finished program's status and its two streams.

    A tuple rather than a record, because a record would have to be a wired-in
    nominal type with wired-in fields — a second way for the compiler to know
    about a shape, for one built-in. `Std.Process` gives it names, in the
    language, where a reader can see them. -}
processValue :: ProcessOutcome -> Value
processValue outcome =
  TupleValue
    [ intOf (processStatus outcome)
    , StrValue (processOutput outcome)
    , StrValue (processErrors outcome)
    ]

textsOf :: Seq.Seq Value -> [Text]
textsOf values = [text | StrValue text <- toList values]

{-| An outcome as the language's own failure carrier. -}
resultOf :: IoOutcome Value -> Value
resultOf outcome = case outcome of
  IoDone value -> VariantValue "Ok" [value]
  IoFailed message -> VariantValue "Err" [StrValue message]

{-| The diagnostic a refused effect reports, built once so the message a reader
    sees does not depend on which effect they reached for. -}
effectRefusal :: Span -> Builtin -> Diagnostic
effectRefusal spanValue builtin =
  fromMaybe (fallbackRefusal spanValue) $ do
    code <- mkDiagnosticCode "E7009"
    value <-
      diagnostic code Error spanValue
        (builtinName builtin <> " reaches outside the program")
    pure
      ( withHelp
          "a compile-time constant is folded while the compiler runs, so it cannot reach the world"
          value
      )

fallbackRefusal :: Span -> Diagnostic
fallbackRefusal spanValue =
  fromMaybe
    (error "the refusal diagnostic must exist")
    (mkDiagnosticCode "E7009" >>= \code -> diagnostic code Error spanValue "effect refused")
