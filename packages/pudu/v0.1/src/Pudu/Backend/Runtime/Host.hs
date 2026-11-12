{-| @Backend.Runtime.Host — every host part in emission order: what the
    program asks of the machine it runs on. A family comes after the
    families its parts call. -}
module Pudu.Backend.Runtime.Host (hostRuntimeParts) where

import Data.Text (Text)
import Pudu.Backend.Runtime.Host.Child (hostChildParts)
import Pudu.Backend.Runtime.Host.Compress (hostCompressParts)
import Pudu.Backend.Runtime.Host.Concurrent (hostConcurrentParts)
import Pudu.Backend.Runtime.Host.File (hostFileParts)
import Pudu.Backend.Runtime.Host.Handle (hostHandleParts)
import Pudu.Backend.Runtime.Host.Input (hostInputParts)
import Pudu.Backend.Runtime.Host.Lanes (hostLaneParts)
import Pudu.Backend.Runtime.Host.Raster (hostRasterParts)
import Pudu.Backend.Runtime.Host.Math (hostMathParts)
import Pudu.Backend.Runtime.Host.Net (hostNetParts)
import Pudu.Backend.Runtime.Host.Process (hostProcessParts)
import Pudu.Backend.Runtime.Host.Scope (hostScopeParts)
import Pudu.Backend.Runtime.Host.Signal (hostSignalParts)
import Pudu.Backend.Runtime.Host.State (hostStateParts)
import Pudu.Backend.Runtime.Host.Time (hostTimeParts)
import Pudu.Backend.Runtime.Host.TimeParse (hostTimeParseParts)
import Pudu.Backend.Runtime.Host.Tls (hostTlsParts)

hostRuntimeParts :: [(Text, [Text], [Text])]
hostRuntimeParts = hostStateParts <> hostMathParts <> hostProcessParts <> hostConcurrentParts
  <> hostInputParts <> hostFileParts <> hostHandleParts <> hostScopeParts <> hostLaneParts <> hostRasterParts <> hostSignalParts <> hostNetParts <> hostTlsParts <> hostCompressParts
  <> hostChildParts <> hostTimeParts <> hostTimeParseParts
