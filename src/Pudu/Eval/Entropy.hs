{-| @Eval.Entropy.Module — operating-system cryptographic randomness -}
module Pudu.Eval.Entropy
  ( secureBytes
  ) where

import Control.Exception (SomeException, try)
import qualified Data.ByteString as ByteString
import qualified Data.Text as Text
import Pudu.Eval.Io (IoOutcome (..))
import System.Entropy (getEntropy)

{-| Obtain security material from the host entropy provider.

    The one-megabyte ceiling prevents an arbitrary-precision Pudu integer from
    becoming an unbounded host allocation. Callers needing more material
    derive or stream it from a bounded seed instead of asking the operating
    system for one enormous buffer. -}
secureBytes :: Integer -> IO (IoOutcome ByteString.ByteString)
secureBytes count
  | count < 0 = pure (IoFailed "the secure byte count cannot be negative")
  | count > 1048576 = pure (IoFailed "the secure byte count cannot exceed 1048576")
  | count == 0 = pure (IoDone ByteString.empty)
  | otherwise = do
      attempted <- try (getEntropy (fromInteger count))
        :: IO (Either SomeException ByteString.ByteString)
      pure $ case attempted of
        Left problem -> IoFailed (Text.pack (show problem))
        Right bytes -> IoDone bytes
