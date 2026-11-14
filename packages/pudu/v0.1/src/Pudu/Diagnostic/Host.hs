{-| @Pudu.Diagnostic.Host — process failures outside Pudu source semantics. -}
module Pudu.Diagnostic.Host (memoryFailureMessage) where

memoryFailureMessage :: String
memoryFailureMessage = "pudu: memory allocation failed"
