{-| @Eval.Sign — Ed25519 signatures over bytes

    A desktop application's release tooling signs every artifact it ships, and
    the installed application verifies each download with the public half it
    carries. Both halves of that live here; the seed itself is generated in
    Pudu from the system's secure random source. -}
module Pudu.Eval.Sign
  ( ed25519PublicOf
  , ed25519Sign
  , ed25519Verify
  ) where

import Crypto.Error (maybeCryptoError)
import qualified Crypto.PubKey.Ed25519 as Ed25519
import qualified Data.ByteArray as ByteArray
import qualified Data.ByteString as ByteString

{-| The public key a 32-byte seed signs for, or nothing for another length. -}
ed25519PublicOf :: ByteString.ByteString -> Maybe ByteString.ByteString
ed25519PublicOf seed = do
  secret <- maybeCryptoError (Ed25519.secretKey seed)
  pure (ByteArray.convert (Ed25519.toPublic secret))

{-| The 64-byte signature of a message under a 32-byte seed. -}
ed25519Sign :: ByteString.ByteString -> ByteString.ByteString -> Maybe ByteString.ByteString
ed25519Sign seed message = do
  secret <- maybeCryptoError (Ed25519.secretKey seed)
  let public = Ed25519.toPublic secret
  pure (ByteArray.convert (Ed25519.sign secret public message))

{-| Whether a signature is genuine; a malformed key or signature is not. -}
ed25519Verify :: ByteString.ByteString -> ByteString.ByteString -> ByteString.ByteString -> Bool
ed25519Verify public message signature =
  case (maybeCryptoError (Ed25519.publicKey public), maybeCryptoError (Ed25519.signature signature)) of
    (Just key, Just checked) -> Ed25519.verify key message checked
    _ -> False
