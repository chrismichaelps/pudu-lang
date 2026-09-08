{-| @Eval.Verify — checking a signature made with someone else's private key

    An identity provider signs the tokens it issues with a private key nobody
    else has, and publishes the public half. Checking a token means checking
    that signature. It cannot be done with a keyed digest, which needs both
    sides to hold the same secret: the whole arrangement exists so that a
    service can verify without being able to forge.

    Only verification is here. Signing needs a private key, and a service that
    verifies tokens from a provider has no reason to hold one; leaving it out
    means there is nothing to leak and nothing to misuse.

    Keys arrive as numbers rather than as a file format, because that is how a
    provider publishes them: a JWKS gives an RSA modulus and exponent, or a
    curve point's two coordinates, each as base64url. Parsing that belongs in
    the library, where a reader can see it. -}
module Pudu.Eval.Verify
  ( verifyRsaSha256
  , verifyEcdsaP256Sha256
  ) where

import qualified Crypto.Hash.Algorithms as Algorithms
import qualified Crypto.Number.Serialize as Number
import qualified Crypto.PubKey.ECC.ECDSA as Ecdsa
import qualified Crypto.PubKey.ECC.Types as Curve
import qualified Crypto.PubKey.RSA as Rsa
import qualified Crypto.PubKey.RSA.PKCS15 as Pkcs15
import qualified Data.ByteString as ByteString

{-| Whether an RSASSA-PKCS1-v1_5 signature over SHA-256 is genuine.

    This is `RS256`, which is what every identity provider a service is likely
    to meet actually issues. The modulus and exponent are the two numbers a
    provider publishes, in the big-endian form its JWKS carries them in.

    A malformed key answers `False` rather than raising: a key comes from
    outside, and a service checking a token should refuse it, not stop. -}
verifyRsaSha256
  :: ByteString.ByteString
  -> ByteString.ByteString
  -> ByteString.ByteString
  -> ByteString.ByteString
  -> Bool
verifyRsaSha256 modulus pubExp message signature
  | ByteString.null modulus || ByteString.null pubExp = False
  | otherwise =
      let n = Number.os2ip modulus
          e = Number.os2ip pubExp
          key = Rsa.PublicKey{Rsa.public_size = ByteString.length modulus, Rsa.public_n = n, Rsa.public_e = e}
       in n > 0 && e > 0 && Pkcs15.verify (Just Algorithms.SHA256) key message signature

{-| Whether an ECDSA signature over SHA-256 on the P-256 curve is genuine.

    This is `ES256`. The signature is the fixed sixty-four byte form a JWT
    carries — the two halves written out to the curve's size — rather than the
    variable-length DER an X.509 certificate carries, because those are not
    interchangeable and a token uses the first.

    A signature of any other length is refused. Reading a shorter one by
    padding it would accept signatures that are not the one that was made. -}
verifyEcdsaP256Sha256
  :: ByteString.ByteString
  -> ByteString.ByteString
  -> ByteString.ByteString
  -> ByteString.ByteString
  -> Bool
verifyEcdsaP256Sha256 x y message signature
  | ByteString.length signature /= 64 = False
  | ByteString.null x || ByteString.null y = False
  | otherwise =
      let (rBytes, sBytes) = ByteString.splitAt 32 signature
          point = Curve.Point (Number.os2ip x) (Number.os2ip y)
          key = Ecdsa.PublicKey (Curve.getCurveByName Curve.SEC_p256r1) point
          made = Ecdsa.Signature (Number.os2ip rBytes) (Number.os2ip sBytes)
       in Ecdsa.verify Algorithms.SHA256 key made message
