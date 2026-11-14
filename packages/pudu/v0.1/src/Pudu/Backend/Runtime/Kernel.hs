{-| @Backend.Runtime.Kernel — every kernel part in emission order, and each
    part's prerequisites. The parts use `pudu_cell`, so they are emitted
    after the frame types. -}
module Pudu.Backend.Runtime.Kernel (kernelRuntimeParts, kernelRuntimeDependencies) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Backend.Runtime.Kernel.Audio (audioKernelParts)
import Pudu.Backend.Runtime.Kernel.Blake2 (blake2KernelParts)
import Pudu.Backend.Runtime.Kernel.Buffer (bufferKernelParts)
import Pudu.Backend.Runtime.Kernel.Bytes (bytesKernelParts)
import Pudu.Backend.Runtime.Kernel.Checksum (checksumKernelParts)
import Pudu.Backend.Runtime.Kernel.Column (columnKernelParts)
import Pudu.Backend.Runtime.Kernel.Csv (csvKernelParts)
import Pudu.Backend.Runtime.Kernel.Json (jsonKernelParts)
import Pudu.Backend.Runtime.Kernel.Mac (macKernelParts)
import Pudu.Backend.Runtime.Kernel.Natural (naturalKernelParts)
import Pudu.Backend.Runtime.Kernel.Seal (sealKernelParts)
import Pudu.Backend.Runtime.Kernel.Sha2 (sha2KernelParts)
import Pudu.Backend.Runtime.Kernel.Sha3 (sha3KernelParts)
import Pudu.Backend.Runtime.Kernel.Sort (sortKernelParts)
import Pudu.Backend.Runtime.Kernel.Swiss (swissKernelParts)
import Pudu.Backend.Runtime.Kernel.Verify (verifyKernelParts)
import Pudu.Backend.Runtime.Kernel.Xml (xmlKernelParts)
import Pudu.Backend.Runtime.Host (hostRuntimeParts)

{-| A family comes after the families its parts call. -}
families :: [(Text, [Text], [Text])]
families = bytesKernelParts <> bufferKernelParts <> columnKernelParts <> sortKernelParts <> swissKernelParts
  <> sha2KernelParts <> sha3KernelParts <> blake2KernelParts <> macKernelParts <> checksumKernelParts
  <> sealKernelParts <> naturalKernelParts <> verifyKernelParts <> audioKernelParts
  <> jsonKernelParts <> xmlKernelParts <> csvKernelParts <> hostRuntimeParts

kernelRuntimeParts :: [(Text, [Text])]
kernelRuntimeParts = [(name, body) | (name, _, body) <- families]

kernelRuntimeDependencies :: Text -> [Text]
kernelRuntimeDependencies name = Map.findWithDefault [] name needs
 where
  needs = Map.fromList [(part, required) | (part, required, _) <- families]
