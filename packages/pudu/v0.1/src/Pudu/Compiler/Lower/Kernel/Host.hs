{-| @Compiler.Lower.Kernel.Host — the monomorphic host builtins: the float
    kernels, the clocks, the process's surroundings, and the locks, channels
    and threads whose signatures hold no type parameter. -}
module Pudu.Compiler.Lower.Kernel.Host (hostPrimitives) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Kernel.Lanes (lanePrimitives)
import Pudu.Compiler.Lower.Kernel.Shape
import Pudu.Core
import Pudu.FloatKernel (KernelShape (..), floatKernelName, floatKernelShape, floatKernels)
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (..))

hostPrimitives :: [(Text, Primitive)]
hostPrimitives = mathPrimitives <> processPrimitives <> concurrentPrimitives <> filePrimitives <> netPrimitives <> tlsPrimitives <> compressPrimitives <> childPrimitives <> lanePrimitives

{-| A host kernel over every operand in order. -}
host :: Text -> Int -> Call
host name count = Call (KernelHost name) [] [0 .. count - 1]

int, f64, text, bytes, unit :: CoreType
int = CoreIntegerType PlatformSigned
f64 = CoreFloatType Float64Width
text = CoreTextType
bytes = CoreBytesType
unit = CoreUnitType

option, outcome, array :: CoreType -> CoreType
option kind = CoreSumType "Option" [kind]
outcome kind = CoreSumType "Result" [kind, CoreTextType]
array = CoreArrayType

{-| Each float kernel under its prelude name; the part is the name without
    its `float` prefix. -}
mathPrimitives :: [(Text, Primitive)]
mathPrimitives = [(floatKernelName kernel, entry (floatKernelName kernel) (floatKernelShape kernel)) | kernel <- floatKernels]
 where
  u64 = CoreIntegerType (UnsignedKind 64)
  entry name shape = case shape of
    FloatArguments count -> Primitive (replicate count f64) f64 [] (Plain (host ("math_" <> Text.toLower (Text.drop 5 name)) count))
    FloatToWord -> Primitive [f64] u64 [] (Plain (host "math_to_bits" 1))
    WordToFloat -> Primitive [u64] f64 [] (Plain (host "math_from_bits" 1))
    IntToFloat -> Primitive [int] f64 [] (Plain (host "math_from_int" 1))
    FloatToInt -> Primitive [f64] (option int) [] (Optional (host "math_whole" 1) (host "math_to_int" 1))

processPrimitives :: [(Text, Primitive)]
processPrimitives =
  [ ("clock", Primitive [] int [] (Plain (host "clock" 0)))
  , ("clockNanos", Primitive [] int [] (Plain (host "clock_nanos" 0)))
  , ("now", Primitive [] int [] (Plain (host "now" 0)))
  , ("zoneOffset", Primitive [] int [] (Plain (host "zone_offset" 0)))
  , ("sleepMillis", Primitive [int] (outcome unit) [] (Outcome (host "sleep" 1)))
  , ("arguments", Primitive [] (array text) [] (Plain (host "arguments" 0)))
  , ("environment", Primitive [] (array (CoreTupleType [text, text])) [] (Plain (host "environment" 0)))
  , ("temporaryPath", Primitive [] text [] (Plain (host "temporary_path" 0)))
  , ("userHome", Primitive [] (option text) [] (Absent (host "user_home" 0)))
  , ("pathSeparators", Primitive [] (array text) [] (Plain (host "path_separators" 0)))
  , ("searchSeparator", Primitive [] text [] (Plain (host "search_separator" 0)))
  , ("exit", Primitive [int] unit [] (Effect (host "exit" 1)))
  , ("secureRandomBytes", Primitive [int] (outcome bytes) [] (Outcome (host "secure_bytes" 1)))
  , ("formatTime", Primitive [text, int, text] (outcome text) [] (Outcome (host "format_time" 3)))
  , ("parseTime", Primitive [text, text] (outcome int) [] (Outcome (host "parse_time" 2)))
  , ("signalWatchStop", Primitive [] CoreBoolType [] (Plain (host "signal_watch" 0)))
  , ("signalStopRequested", Primitive [] CoreBoolType [] (Plain (host "signal_requested" 0)))
  ]

concurrentPrimitives :: [(Text, Primitive)]
concurrentPrimitives =
  [ ("cellDispose", Primitive [int] (outcome unit) [] (Outcome (host "cell_dispose" 1)))
  , ("mutexOpen", Primitive [] int [] (Plain (host "mutex_open" 0)))
  , ("mutexAcquire", Primitive [int] (outcome unit) [] (Outcome (host "mutex_acquire" 1)))
  , ("mutexAcquireWithin", Primitive [int, int] (outcome CoreBoolType) [] (Outcome (host "mutex_acquire_within" 2)))
  , ("mutexRelease", Primitive [int] (outcome unit) [] (Outcome (host "mutex_release" 1)))
  , ("mutexDispose", Primitive [int] (outcome unit) [] (Outcome (host "mutex_dispose" 1)))
  , ("channelOpen", Primitive [int] int [] (Plain (host "channel_open" 1)))
  , ("channelWaiting", Primitive [int] (outcome int) [] (Outcome (host "channel_waiting" 1)))
  , ("channelFinish", Primitive [int] (outcome unit) [] (Outcome (host "channel_finish" 1)))
  , ("joinThread", Primitive [int] (outcome unit) [] (Outcome (host "thread_join" 1)))
  , ("forgetThread", Primitive [int] (outcome unit) [] (Outcome (host "thread_forget" 1)))
  ]

{-| A host kernel with one fixed integer after its operands. -}
moded :: Text -> Int -> Int -> Call
moded name mode count = Call (KernelHost name) [mode] [0 .. count - 1]

filePrimitives :: [(Text, Primitive)]
filePrimitives =
  [ ("readFile", Primitive [text] (outcome text) [] (Outcome (host "read_file" 1)))
  , ("writeFile", Primitive [text, text] (outcome unit) [] (Outcome (moded "write_file" 0 2)))
  , ("appendFile", Primitive [text, text] (outcome unit) [] (Outcome (moded "write_file" 1 2)))
  , ("fileExists", Primitive [text] CoreBoolType [] (Plain (moded "file_exists" 0 1)))
  , ("directoryExists", Primitive [text] CoreBoolType [] (Plain (moded "file_exists" 1 1)))
  , ("removeFile", Primitive [text] (outcome unit) [] (Outcome (moded "path_step" 0 1)))
  , ("createDirectoryExclusive", Primitive [text] (outcome unit) [] (Outcome (moded "path_step" 1 1)))
  , ("removeEmptyDirectory", Primitive [text] (outcome unit) [] (Outcome (moded "path_step" 2 1)))
  , ("createDirectory", Primitive [text] (outcome unit) [] (Outcome (host "create_directory" 1)))
  , ("renamePath", Primitive [text, text] (outcome unit) [] (Outcome (host "rename_path" 2)))
  , ("fileSize", Primitive [text] (outcome int) [] (Outcome (host "file_size" 1)))
  , ("permissionsOf", Primitive [text] (outcome int) [] (Outcome (host "permissions_of" 1)))
  , ("setPermissionsOf", Primitive [text, int] (outcome unit) [] (Outcome (host "set_permissions_of" 2)))
  , ("pathIsSymbolicLink", Primitive [text] (outcome CoreBoolType) [] (Outcome (host "is_symbolic_link" 1)))
  , ("createSymbolicLink", Primitive [text, text] (outcome unit) [] (Outcome (host "create_symbolic_link" 2)))
  , ("canonicalPath", Primitive [text] (outcome text) [] (Outcome (host "canonical_path" 1)))
  , ("listDirectory", Primitive [text] (outcome (array text)) [] (Outcome (host "list_directory" 1)))
  , ("createTemporaryFile", Primitive [text, text] (outcome text) [] (Outcome (host "create_temporary_file" 2)))
  , ("writeFileAtomically", Primitive [text, bytes] (outcome unit) [] (Outcome (host "write_atomically" 2)))
  , ("openReader", Primitive [text] (outcome int) [] (Outcome (moded "open_handle" 0 1)))
  , ("openWriter", Primitive [text] (outcome int) [] (Outcome (moded "open_handle" 1 1)))
  , ("openAppender", Primitive [text] (outcome int) [] (Outcome (moded "open_handle" 2 1)))
  , ("readChunk", Primitive [int, int] (outcome (option bytes)) [] (OutcomeOptional (host "read_chunk" 2)))
  , ("writeChunk", Primitive [int, bytes] (outcome unit) [] (Outcome (host "write_chunk" 2)))
  , ("flushWriter", Primitive [int] (outcome unit) [] (Outcome (host "flush_writer" 1)))
  , ("closeHandle", Primitive [int] (outcome unit) [] (Outcome (host "close_handle" 1)))
  ]

netPrimitives :: [(Text, Primitive)]
netPrimitives =
  [ ("tcpListen", Primitive [text, int, int] (outcome int) [] (Outcome (host "tcp_listen" 3)))
  , ("tcpAccept", Primitive [int] (outcome int) [] (Outcome (host "tcp_accept" 1)))
  , ("tcpConnect", Primitive [text, int] (outcome int) [] (Outcome (host "tcp_connect" 2)))
  , ("tcpConnectWithin", Primitive [text, int, int] (outcome int) [] (Outcome (host "tcp_connect_within" 3)))
  , ("socketSend", Primitive [int, bytes] (outcome unit) [] (Outcome (host "socket_send" 2)))
  , ("socketSendWithin", Primitive [int, bytes, int] (outcome unit) [] (Outcome (host "socket_send_within" 3)))
  , ("socketReceive", Primitive [int, int] (outcome (option bytes)) [] (OutcomeOptional (host "socket_receive" 2)))
  , ("socketReceiveWithin", Primitive [int, int, int] (outcome (option bytes)) [] (OutcomeOptional (host "socket_receive_within" 3)))
  , ("socketClose", Primitive [int] (outcome unit) [] (Outcome (host "socket_close" 1)))
  , ("socketFinish", Primitive [int] (outcome unit) [] (Outcome (host "socket_finish" 1)))
  , ("socketPeer", Primitive [int] (outcome text) [] (Outcome (host "socket_peer" 1)))
  , ("socketPort", Primitive [int] (outcome int) [] (Outcome (host "socket_port" 1)))
  ]

tlsPrimitives :: [(Text, Primitive)]
tlsPrimitives =
  [ ("tlsConnect", Primitive [text, int] (outcome int) [] (Outcome (host "tls_connect" 2)))
  , ("tlsConnectWithin", Primitive [text, int, int] (outcome int) [] (Outcome (host "tls_connect_within" 3)))
  , ("tlsUpgradeWithin", Primitive [int, text, int] (outcome int) [] (Outcome (host "tls_upgrade_within" 3)))
  , ("tlsSend", Primitive [int, bytes] (outcome unit) [] (Outcome (host "tls_send" 2)))
  , ("tlsSendWithin", Primitive [int, bytes, int] (outcome unit) [] (Outcome (host "tls_send_within" 3)))
  , ("tlsReceive", Primitive [int, int] (outcome (option bytes)) [] (OutcomeOptional (host "tls_receive" 2)))
  , ("tlsReceiveWithin", Primitive [int, int, int] (outcome (option bytes)) [] (OutcomeOptional (host "tls_receive_within" 3)))
  , ("tlsClose", Primitive [int] (outcome unit) [] (Outcome (host "tls_close" 1)))
  , ("tlsCloseWithin", Primitive [int, int] (outcome unit) [] (Outcome (host "tls_close_within" 2)))
  , ("tlsPeer", Primitive [int] (outcome text) [] (Outcome (host "tls_peer" 1)))
  ]

compressPrimitives :: [(Text, Primitive)]
compressPrimitives =
  [ ("gzipCompress", Primitive [bytes, int, int] (outcome bytes) [] (Outcome (moded "deflate" 0 3)))
  , ("deflateRaw", Primitive [bytes, int, int] (outcome bytes) [] (Outcome (moded "deflate" 1 3)))
  , ("gzipDecompress", Primitive [bytes, int] (outcome bytes) [] (Outcome (moded "inflate" 0 2)))
  , ("inflateRaw", Primitive [bytes, int] (outcome bytes) [] (Outcome (moded "inflate" 1 2)))
  ]

childPrimitives :: [(Text, Primitive)]
childPrimitives =
  [ ("spawnProgram", Primitive [text, array text] (outcome int) [] (Outcome (host "child_spawn" 2)))
  , ("spawnProgramWith", Primitive [text, array text, array (CoreTupleType [text, text]), CoreBoolType, text] (outcome int) []
      (Outcome (host "child_spawn_with" 5)))
  , ("childReadChunk", Primitive [int, int] (outcome (option bytes)) [] (OutcomeOptional (moded "child_read" 0 2)))
  , ("childReadErrorChunk", Primitive [int, int] (outcome (option bytes)) [] (OutcomeOptional (moded "child_read" 1 2)))
  , ("childWriteChunk", Primitive [int, bytes] (outcome unit) [] (Outcome (host "child_write" 2)))
  , ("childCloseInput", Primitive [int] (outcome unit) [] (Outcome (host "child_close_input" 1)))
  , ("childWait", Primitive [int] (outcome int) [] (Outcome (host "child_wait" 1)))
  , ("childWaitWithin", Primitive [int, int] (outcome (option int)) [] (OutcomeOptional (host "child_wait_within" 2)))
  , ("childStop", Primitive [int] (outcome int) [] (Outcome (host "child_stop" 1)))
  , ("runProgram", Primitive [text, array text, text] (outcome (CoreTupleType [int, text, text])) [] (Outcome (host "run_program" 3)))
  ]
