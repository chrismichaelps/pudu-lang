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
  | WordMapUnionBuiltin
  | WordMapIntersectionBuiltin
  | WordMapDifferenceBuiltin
  | WordMapSymmetricDifferenceBuiltin
  | WordMapIsSubsetOfBuiltin
  | WordMapIsDisjointFromBuiltin
  | WordMapPopCountBuiltin
  | WordMapMembersBuiltin
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
  | BufferAllocBuiltin
  | BufferReadU64Builtin
  | BufferWriteU64Builtin
  | BufferScanU64Builtin
  | BufferCopyBuiltin
  | BufferSizeBuiltin
  | SwissTableEmptyBuiltin
  | SwissTableLookupBuiltin
  | SwissTableInsertBuiltin
  | SwissTableDeleteBuiltin
  | SwissTableEntriesBuiltin
  | SwissTableSizeBuiltin
  | BufferReadI64Builtin
  | BufferWriteI64Builtin
  | BufferReadF64Builtin
  | BufferWriteF64Builtin
  | BufferReadU32Builtin
  | BufferWriteU32Builtin
  | BufferFillBuiltin
  | BufferCompareBuiltin
  | ColumnSumU64Builtin
  | ColumnMinU64Builtin
  | ColumnMaxU64Builtin
  | ColumnFilterGtU64Builtin
  | ColumnProjectU64Builtin
  | ColumnSumF64Builtin
  | ColumnMinF64Builtin
  | ColumnMaxF64Builtin
  | ColumnFilterGtF64Builtin
  | ColumnFilterLtF64Builtin
  | ColumnProjectF64Builtin
  | ColumnAddF64Builtin
  | ColumnBitmapAndBuiltin
  | ColumnBitmapOrBuiltin
  | ColumnBitmapNotBuiltin
  | ColumnBitmapCountBuiltin
  | ColumnSortIndicesU64Builtin
  | ColumnSortIndicesF64Builtin
  | ColumnBinarySearchU64Builtin
  | ColumnBinarySearchF64Builtin
  | ColumnGatherU64Builtin
  | ColumnGatherF64Builtin
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
  WordMapUnionBuiltin -> "wordMapUnion"
  WordMapIntersectionBuiltin -> "wordMapIntersection"
  WordMapDifferenceBuiltin -> "wordMapDifference"
  WordMapSymmetricDifferenceBuiltin -> "wordMapSymmetricDifference"
  WordMapIsSubsetOfBuiltin -> "wordMapIsSubsetOf"
  WordMapIsDisjointFromBuiltin -> "wordMapIsDisjointFrom"
  WordMapPopCountBuiltin -> "wordMapPopCount"
  WordMapMembersBuiltin -> "wordMapMembers"
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
  BufferAllocBuiltin -> "bufferAlloc"
  BufferReadU64Builtin -> "bufferReadU64"
  BufferWriteU64Builtin -> "bufferWriteU64"
  BufferScanU64Builtin -> "bufferScanU64"
  BufferCopyBuiltin -> "bufferCopy"
  BufferSizeBuiltin -> "bufferSize"
  SwissTableEmptyBuiltin -> "swissTableEmpty"
  SwissTableLookupBuiltin -> "swissTableLookup"
  SwissTableInsertBuiltin -> "swissTableInsert"
  SwissTableDeleteBuiltin -> "swissTableDelete"
  SwissTableEntriesBuiltin -> "swissTableEntries"
  SwissTableSizeBuiltin -> "swissTableSize"
  BufferReadI64Builtin -> "bufferReadI64"
  BufferWriteI64Builtin -> "bufferWriteI64"
  BufferReadF64Builtin -> "bufferReadF64"
  BufferWriteF64Builtin -> "bufferWriteF64"
  BufferReadU32Builtin -> "bufferReadU32"
  BufferWriteU32Builtin -> "bufferWriteU32"
  BufferFillBuiltin -> "bufferFill"
  BufferCompareBuiltin -> "bufferCompare"
  ColumnSumU64Builtin -> "columnSumU64"
  ColumnMinU64Builtin -> "columnMinU64"
  ColumnMaxU64Builtin -> "columnMaxU64"
  ColumnFilterGtU64Builtin -> "columnFilterGtU64"
  ColumnProjectU64Builtin -> "columnProjectU64"
  ColumnSumF64Builtin -> "columnSumF64"
  ColumnMinF64Builtin -> "columnMinF64"
  ColumnMaxF64Builtin -> "columnMaxF64"
  ColumnFilterGtF64Builtin -> "columnFilterGtF64"
  ColumnFilterLtF64Builtin -> "columnFilterLtF64"
  ColumnProjectF64Builtin -> "columnProjectF64"
  ColumnAddF64Builtin -> "columnAddF64"
  ColumnBitmapAndBuiltin -> "columnBitmapAnd"
  ColumnBitmapOrBuiltin -> "columnBitmapOr"
  ColumnBitmapNotBuiltin -> "columnBitmapNot"
  ColumnBitmapCountBuiltin -> "columnBitmapCount"
  ColumnSortIndicesU64Builtin -> "columnSortIndicesU64"
  ColumnSortIndicesF64Builtin -> "columnSortIndicesF64"
  ColumnBinarySearchU64Builtin -> "columnBinarySearchU64"
  ColumnBinarySearchF64Builtin -> "columnBinarySearchF64"
  ColumnGatherU64Builtin -> "columnGatherU64"
  ColumnGatherF64Builtin -> "columnGatherF64"
