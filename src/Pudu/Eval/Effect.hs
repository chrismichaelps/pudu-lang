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
import Pudu.Eval.Concurrent
  ( cellNew
  , cellRead
  , cellSwap
  , channelClose
  , channelNew
  , channelPending
  , channelReceive
  , channelSend
  , mutexLock
  , mutexNew
  , mutexUnlock
  , sleepFor
  , threadJoin
  )
import Pudu.Eval.Tls
  ( closeTlsAt
  , receiveTls
  , secureConnect
  , sendTls
  , tlsPeerName
  )
import Pudu.Eval.Socket
  ( acceptOn
  , closeSocketAt
  , connectTo
  , listenOn
  , localPortOf
  , peerOf
  , receiveFrom
  , sendOn
  , shutdownWriteAt
  )
import Pudu.Eval.Io
import Pudu.Eval.Entropy (secureBytes)
import Pudu.Eval.Env
  ( effectsAdmitted
  , currentConcurrentStore
  , currentHandleStore
  , currentSocketStore
  , currentTlsStore
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
  , TcpListenBuiltin
  , TcpAcceptBuiltin
  , TcpConnectBuiltin
  , SocketSendBuiltin
  , SocketReceiveBuiltin
  , SocketCloseBuiltin
  , SocketPeerBuiltin
  , SocketPortBuiltin
  , SocketFinishBuiltin
  , TlsConnectBuiltin
  , TlsSendBuiltin
  , TlsReceiveBuiltin
  , TlsCloseBuiltin
  , TlsPeerBuiltin
  , SpawnThreadBuiltin
  , JoinThreadBuiltin
  , SleepBuiltin
  , ChannelOpenBuiltin
  , ChannelPushBuiltin
  , ChannelPullBuiltin
  , ChannelWaitingBuiltin
  , ChannelFinishBuiltin
  , MutexOpenBuiltin
  , MutexAcquireBuiltin
  , MutexReleaseBuiltin
  , CellOpenBuiltin
  , CellGetBuiltin
  , CellSwapBuiltin
  , SecureBytesBuiltin
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
  handles <- currentHandleStore
  sockets <- currentSocketStore
  concurrent <- currentConcurrentStore
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
        resultOf . fmap intOf . fmap fromIntegral <$> lift refusal (openReadHandle handles (Text.unpack path))
      (OpenWriterBuiltin, [StrValue path]) ->
        resultOf . fmap intOf . fmap fromIntegral <$> lift refusal (openWriteHandle handles (Text.unpack path))
      (OpenAppenderBuiltin, [StrValue path]) ->
        resultOf . fmap intOf . fmap fromIntegral <$> lift refusal (openAppendHandle handles (Text.unpack path))
      {-| Nothing read means the input has ended, which is a different answer
          from an empty chunk: a reader that could not tell them apart would
          either stop early or never stop. -}
      (ReadChunkBuiltin, [IntValue _ token, IntValue _ count]) -> do
        outcome <- lift refusal (readHandleChunk handles (fromInteger token) (fromInteger count))
        pure (resultOf (fmap optionalBytes outcome))
      (WriteChunkBuiltin, [IntValue _ token, BytesValue chunk]) ->
        effectUnit (writeHandleChunk handles (fromInteger token) chunk)
      (FlushWriterBuiltin, [IntValue _ token]) ->
        effectUnit (flushHandleAt handles (fromInteger token))
      (CloseHandleBuiltin, [IntValue _ token]) ->
        effectUnit (closeHandleAt handles (fromInteger token))
      {-| An endpoint is named by a token for the reason an open file is: it is
          one object with one position in its stream, while a value is copied
          through evaluation. -}
      (TcpListenBuiltin, [StrValue host, IntValue _ port, IntValue _ backlog]) ->
        resultOf . fmap (intOf . fromIntegral)
          <$> lift refusal (listenOn sockets host (fromInteger port) (fromInteger backlog))
      (TcpAcceptBuiltin, [IntValue _ token]) ->
        resultOf . fmap (intOf . fromIntegral) <$> lift refusal (acceptOn sockets (fromInteger token))
      (TcpConnectBuiltin, [StrValue host, IntValue _ port]) ->
        resultOf . fmap (intOf . fromIntegral)
          <$> lift refusal (connectTo sockets host (fromInteger port))
      (SocketSendBuiltin, [IntValue _ token, BytesValue payload]) ->
        effectUnit (sendOn sockets (fromInteger token) payload)
      (SocketReceiveBuiltin, [IntValue _ token, IntValue _ count]) -> do
        outcome <- lift refusal (receiveFrom sockets (fromInteger token) (fromInteger count))
        pure (resultOf (fmap optionalBytes outcome))
      (SocketCloseBuiltin, [IntValue _ token]) ->
        effectUnit (closeSocketAt sockets (fromInteger token))
      (SocketFinishBuiltin, [IntValue _ token]) ->
        effectUnit (shutdownWriteAt sockets (fromInteger token))
      (SocketPeerBuiltin, [IntValue _ token]) ->
        resultOf . fmap StrValue <$> lift refusal (peerOf sockets (fromInteger token))
      {-| A secured connection is named by a token like a plain one, and the
          verification that makes it secure happens once, when it opens. There
          is no operation here that can turn it off. -}
      (TlsConnectBuiltin, [StrValue host, IntValue _ port]) -> do
        store <- currentTlsStore
        resultOf . fmap (intOf . fromIntegral)
          <$> lift refusal (secureConnect store host (fromInteger port))
      (TlsSendBuiltin, [IntValue _ token, BytesValue payload]) -> do
        store <- currentTlsStore
        effectUnit (sendTls store (fromInteger token) payload)
      (TlsReceiveBuiltin, [IntValue _ token, IntValue _ count]) -> do
        store <- currentTlsStore
        outcome <- lift refusal (receiveTls store (fromInteger token) (fromInteger count))
        pure (resultOf (fmap optionalBytes outcome))
      (TlsCloseBuiltin, [IntValue _ token]) -> do
        store <- currentTlsStore
        effectUnit (closeTlsAt store (fromInteger token))
      (TlsPeerBuiltin, [IntValue _ token]) -> do
        store <- currentTlsStore
        resultOf . fmap StrValue <$> lift refusal (tlsPeerName store (fromInteger token))
      (SocketPortBuiltin, [IntValue _ token]) ->
        resultOf . fmap (intOf . fromIntegral) <$> lift refusal (localPortOf sockets (fromInteger token))
      {-| A thread, a channel, a lock, and a cell are each named by a token for
          the reason a file and a socket are: they are shared objects, while a
          value is copied through evaluation, and two copies of a lock would
          not exclude each other. -}
      (JoinThreadBuiltin, [IntValue _ token]) ->
        effectUnit (threadJoin concurrent (fromInteger token))
      (SleepBuiltin, [IntValue _ millis]) -> effectUnit (sleepFor (fromInteger millis))
      (ChannelOpenBuiltin, [IntValue _ limit]) ->
        intOf . fromIntegral <$> lift refusal (channelNew concurrent (fromInteger limit))
      (ChannelPushBuiltin, [IntValue _ token, value]) ->
        effectUnit (channelSend concurrent (fromInteger token) value)
      (ChannelPullBuiltin, [IntValue _ token]) -> do
        outcome <- lift refusal (channelReceive concurrent (fromInteger token))
        pure (resultOf (fmap optionalValue outcome))
      (ChannelWaitingBuiltin, [IntValue _ token]) ->
        resultOf . fmap (intOf . fromIntegral) <$> lift refusal (channelPending concurrent (fromInteger token))
      (ChannelFinishBuiltin, [IntValue _ token]) ->
        effectUnit (channelClose concurrent (fromInteger token))
      (MutexOpenBuiltin, []) -> intOf . fromIntegral <$> lift refusal (mutexNew concurrent)
      (MutexAcquireBuiltin, [IntValue _ token]) ->
        effectUnit (mutexLock concurrent (fromInteger token))
      (MutexReleaseBuiltin, [IntValue _ token]) ->
        effectUnit (mutexUnlock concurrent (fromInteger token))
      (CellOpenBuiltin, [value]) -> intOf . fromIntegral <$> lift refusal (cellNew concurrent value)
      (CellGetBuiltin, [IntValue _ token]) ->
        resultOf <$> lift refusal (cellRead concurrent (fromInteger token))
      (CellSwapBuiltin, [IntValue _ token, value]) ->
        resultOf <$> lift refusal (cellSwap concurrent (fromInteger token) value)
      (SecureBytesBuiltin, [IntValue _ count]) ->
        resultOf . fmap BytesValue <$> lift refusal (secureBytes count)
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
  optionalValue found = case found of
    Just value -> VariantValue "Some" [value]
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
