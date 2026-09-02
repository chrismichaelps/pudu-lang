{-| @Eval.Builtin.Definition — names the evaluator's wired-in functions. -}
module Pudu.Eval.Builtin.Definition
  ( Builtin (..)
  , builtinName
  ) where

import Data.Text (Text)

{-| A wired-in function the evaluator recognizes by name rather than by closure. -}
data Builtin
  = PanicBuiltin
  | CharFromCodeBuiltin
  | MapOfBuiltin
  | SetOfBuiltin
  | BytesOfBuiltin
  | BucketsOfBuiltin
  | ShowBuiltin
  | DisplayBuiltin
  | PrintBuiltin
  | PrintErrorBuiltin
  | PrintPartBuiltin
  | PrintErrorPartBuiltin
  | ReadLineBuiltin
  | ReadFileBuiltin
  | WriteFileBuiltin
  | AppendFileBuiltin
  | FileExistsBuiltin
  | RemoveFileBuiltin
  | ListDirectoryBuiltin
  | OpenReaderBuiltin
  | OpenWriterBuiltin
  | OpenAppenderBuiltin
  | ReadChunkBuiltin
  | WriteChunkBuiltin
  | FlushWriterBuiltin
  | CloseHandleBuiltin
  | TcpListenBuiltin
  | TcpAcceptBuiltin
  | TcpConnectBuiltin
  | TcpConnectWithinBuiltin
  | SocketSendBuiltin
  | SocketSendWithinBuiltin
  | SocketReceiveBuiltin
  | SocketReceiveWithinBuiltin
  | SocketCloseBuiltin
  | SocketPeerBuiltin
  | SocketPortBuiltin
  | SocketFinishBuiltin
  | TlsConnectBuiltin
  | TlsConnectWithinBuiltin
  | TlsSendBuiltin
  | TlsSendWithinBuiltin
  | TlsReceiveBuiltin
  | TlsReceiveWithinBuiltin
  | TlsCloseBuiltin
  | TlsCloseWithinBuiltin
  | TlsPeerBuiltin
  | SpawnThreadBuiltin
  | JoinThreadBuiltin
  | SleepBuiltin
  | ChannelOpenBuiltin
  | ChannelPushBuiltin
  | ChannelPullBuiltin
  | ChannelWaitingBuiltin
  | ChannelFinishBuiltin
  | MutexOpenBuiltin
  | MutexAcquireBuiltin
  | MutexReleaseBuiltin
  | CellOpenBuiltin
  | CellGetBuiltin
  | CellSwapBuiltin
  | SecureBytesBuiltin
  | Sha256Builtin
  | HmacBuiltin
  | DeriveKeyBuiltin
  | HashOfBuiltin
  | MixHashBuiltin
  | CreateDirectoryBuiltin
  | ArgumentsBuiltin
  | EnvironmentBuiltin
  | TemporaryDirectoryBuiltin
  | HomeDirectoryBuiltin
  | PathSeparatorsBuiltin
  | SearchSeparatorBuiltin
  | ExitBuiltin
  | ClockBuiltin
  | NowBuiltin
  | FormatTimeBuiltin
  | ParseTimeBuiltin
  | ZoneOffsetBuiltin
  | RunBuiltin
  | ConvertIntegerBuiltin
  | DecimalOfBuiltin
  | DecimalFromIntBuiltin
  | DecimalScaleBuiltin
  | DecimalToIntBuiltin
  | DecimalToFloatBuiltin
  | DecimalDivideBuiltin
  | DecimalRoundBuiltin
  deriving stock (Eq, Show)

{-| The source-level binding for a built-in tag. -}
builtinName :: Builtin -> Text
builtinName value = case value of
  PanicBuiltin -> "panic"
  CharFromCodeBuiltin -> "charFromCode"
  MapOfBuiltin -> "mapOf"
  SetOfBuiltin -> "setOf"
  BytesOfBuiltin -> "bytesOf"
  BucketsOfBuiltin -> "bucketsOf"
  ShowBuiltin -> "show"
  DisplayBuiltin -> "display"
  PrintBuiltin -> "print"
  PrintErrorBuiltin -> "printError"
  PrintPartBuiltin -> "printPart"
  PrintErrorPartBuiltin -> "printErrorPart"
  ReadLineBuiltin -> "readLine"
  ReadFileBuiltin -> "readFile"
  WriteFileBuiltin -> "writeFile"
  AppendFileBuiltin -> "appendFile"
  FileExistsBuiltin -> "fileExists"
  RemoveFileBuiltin -> "removeFile"
  ListDirectoryBuiltin -> "listDirectory"
  OpenReaderBuiltin -> "openReader"
  OpenWriterBuiltin -> "openWriter"
  OpenAppenderBuiltin -> "openAppender"
  ReadChunkBuiltin -> "readChunk"
  WriteChunkBuiltin -> "writeChunk"
  FlushWriterBuiltin -> "flushWriter"
  CloseHandleBuiltin -> "closeHandle"
  TcpListenBuiltin -> "tcpListen"
  TcpAcceptBuiltin -> "tcpAccept"
  TcpConnectBuiltin -> "tcpConnect"
  TcpConnectWithinBuiltin -> "tcpConnectWithin"
  SocketSendBuiltin -> "socketSend"
  SocketSendWithinBuiltin -> "socketSendWithin"
  SocketReceiveBuiltin -> "socketReceive"
  SocketReceiveWithinBuiltin -> "socketReceiveWithin"
  SocketCloseBuiltin -> "socketClose"
  SocketPeerBuiltin -> "socketPeer"
  SocketPortBuiltin -> "socketPort"
  SocketFinishBuiltin -> "socketFinish"
  TlsConnectBuiltin -> "tlsConnect"
  TlsConnectWithinBuiltin -> "tlsConnectWithin"
  TlsSendBuiltin -> "tlsSend"
  TlsSendWithinBuiltin -> "tlsSendWithin"
  TlsReceiveBuiltin -> "tlsReceive"
  TlsReceiveWithinBuiltin -> "tlsReceiveWithin"
  TlsCloseBuiltin -> "tlsClose"
  TlsCloseWithinBuiltin -> "tlsCloseWithin"
  TlsPeerBuiltin -> "tlsPeer"
  SpawnThreadBuiltin -> "spawnThread"
  JoinThreadBuiltin -> "joinThread"
  SleepBuiltin -> "sleepMillis"
  ChannelOpenBuiltin -> "channelOpen"
  ChannelPushBuiltin -> "channelPush"
  ChannelPullBuiltin -> "channelPull"
  ChannelWaitingBuiltin -> "channelWaiting"
  ChannelFinishBuiltin -> "channelFinish"
  MutexOpenBuiltin -> "mutexOpen"
  MutexAcquireBuiltin -> "mutexAcquire"
  MutexReleaseBuiltin -> "mutexRelease"
  CellOpenBuiltin -> "cellOpen"
  CellGetBuiltin -> "cellGet"
  CellSwapBuiltin -> "cellSwap"
  SecureBytesBuiltin -> "secureRandomBytes"
  Sha256Builtin -> "sha256Of"
  HmacBuiltin -> "hmacSha256Of"
  DeriveKeyBuiltin -> "deriveKey"
  HashOfBuiltin -> "hashOf"
  MixHashBuiltin -> "mixHash"
  CreateDirectoryBuiltin -> "createDirectory"
  ArgumentsBuiltin -> "arguments"
  EnvironmentBuiltin -> "environment"
  TemporaryDirectoryBuiltin -> "temporaryPath"
  HomeDirectoryBuiltin -> "userHome"
  PathSeparatorsBuiltin -> "pathSeparators"
  SearchSeparatorBuiltin -> "searchSeparator"
  ExitBuiltin -> "exit"
  ClockBuiltin -> "clock"
  NowBuiltin -> "now"
  FormatTimeBuiltin -> "formatTime"
  ParseTimeBuiltin -> "parseTime"
  ZoneOffsetBuiltin -> "zoneOffset"
  RunBuiltin -> "runProgram"
  ConvertIntegerBuiltin -> "convertInteger"
  DecimalOfBuiltin -> "decimalOf"
  DecimalFromIntBuiltin -> "decimalFromInt"
  DecimalScaleBuiltin -> "decimalScale"
  DecimalToIntBuiltin -> "decimalToInt"
  DecimalToFloatBuiltin -> "decimalToFloat"
  DecimalDivideBuiltin -> "decimalDivide"
  DecimalRoundBuiltin -> "decimalRound"
