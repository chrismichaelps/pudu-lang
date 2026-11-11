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
hostPrimitives = mathPrimitives <> processPrimitives <> concurrentPrimitives <> filePrimitives <> lanePrimitives

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
