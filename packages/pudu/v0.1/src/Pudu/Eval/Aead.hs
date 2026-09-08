{-| @Eval.Aead — encryption that also proves the message was not altered

    A cipher on its own hides a message and says nothing about whether it
    arrived as it was sent. That gap is not academic: an attacker who cannot
    read a message can still change it, and a program that decrypts whatever
    it is handed will act on the result. Authenticated encryption closes the
    gap by producing a tag over the ciphertext and the unencrypted context
    beside it, and refusing to decrypt anything whose tag does not agree.

    ChaCha20-Poly1305 rather than AES-GCM: it needs no hardware support to run
    at a sensible speed and in constant time, which matters for a language that
    also runs where AES instructions do not exist. Both are the same
    construction to a caller — key, nonce, message, associated data — so a
    program written against this is not written against the choice.

    The one rule a caller must keep is that a nonce is used once per key.
    Reusing one does not merely weaken the encryption, it reveals the messages,
    so `Std.Crypto` derives nonces rather than letting a caller pick them. -}
module Pudu.Eval.Aead
  ( sealBytes
  , openBytes
  ) where

import qualified Crypto.Cipher.ChaChaPoly1305 as ChaCha
import Crypto.Error (CryptoFailable (CryptoFailed, CryptoPassed))
import qualified Data.ByteArray as ByteArray
import qualified Data.ByteString as ByteString

{-| The length of a key, in bytes. -}
keyLength :: Int
keyLength = 32

{-| The length of a nonce, in bytes. -}
nonceLength :: Int
nonceLength = 12

{-| The length of the tag appended to every sealed message. -}
tagLength :: Int
tagLength = 16

{-| Encrypt and authenticate, answering the ciphertext with its tag appended.

    The tag travels with the ciphertext rather than beside it, so a caller
    cannot store one and lose the other — which would leave a message that
    decrypts and cannot be checked.

    `Nothing` means the key or the nonce was the wrong length. That is a
    mistake in the program rather than a fact about the message, and it is
    answered rather than raised so `Std.Crypto` can name it. -}
sealBytes
  :: ByteString.ByteString
  -> ByteString.ByteString
  -> ByteString.ByteString
  -> ByteString.ByteString
  -> Maybe ByteString.ByteString
sealBytes key nonce plaintext associated
  | ByteString.length key /= keyLength = Nothing
  | ByteString.length nonce /= nonceLength = Nothing
  | otherwise = do
      state <- start key nonce associated
      let (ciphertext, afterwards) = ChaCha.encrypt plaintext state
          tag = ChaCha.finalize afterwards
      pure (ciphertext <> ByteArray.convert tag)

{-| Check the tag and decrypt, or answer nothing.

    Nothing is answered for every reason a message might not be genuine — a
    wrong key, a changed byte, a truncated message, associated data that does
    not match — because telling them apart tells whoever changed the message
    which change got closer. -}
openBytes
  :: ByteString.ByteString
  -> ByteString.ByteString
  -> ByteString.ByteString
  -> ByteString.ByteString
  -> Maybe ByteString.ByteString
openBytes key nonce sealed associated
  | ByteString.length key /= keyLength = Nothing
  | ByteString.length nonce /= nonceLength = Nothing
  | ByteString.length sealed < tagLength = Nothing
  | otherwise = do
      let split = ByteString.length sealed - tagLength
          (ciphertext, carried) = ByteString.splitAt split sealed
      state <- start key nonce associated
      let (plaintext, afterwards) = ChaCha.decrypt ciphertext state
          computed = ByteArray.convert (ChaCha.finalize afterwards) :: ByteString.ByteString
      -- Compared with the library's own equality on authentication tags, which
      -- takes the same time whatever the difference is. A comparison that
      -- stopped at the first wrong byte would say how much of a forged tag was
      -- right, and that is enough to build the rest of it.
      if ByteArray.constEq computed carried
        then Just plaintext
        else Nothing

start
  :: ByteString.ByteString
  -> ByteString.ByteString
  -> ByteString.ByteString
  -> Maybe ChaCha.State
start key nonce associated = case ChaCha.nonce12 nonce of
  CryptoFailed _ -> Nothing
  CryptoPassed prepared -> case ChaCha.initialize key prepared of
    CryptoFailed _ -> Nothing
    CryptoPassed state -> Just (ChaCha.finalizeAAD (ChaCha.appendAAD associated state))
