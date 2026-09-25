{-| @Test.Version — the source digest a runtime is compared by -}
module Pudu.VersionSpec (versionProperties) where

import qualified Data.ByteString.Char8 as Char8
import qualified Data.Text as Text
import Pudu.Version (digestIn, identityText, sourceDigest, versionText)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

{-| The digest reads back out of bytes that carry it, and only a well-formed
    literal counts: the bare prefix, a short digest, capitals, and a missing
    terminator are passed over, so neither a needle nor a damaged copy is
    mistaken for an identity. -}
versionProperties :: [(String, IO Property)]
versionProperties = [("a runtime's source digest reads back from its bytes", pure digestLaws)]

digestLaws :: Property
digestLaws =
  conjoin
    [ counterexample "the digest is sixty-four hex digits"
        (Text.length sourceDigest === 64)
    , counterexample "the identity names the version and the digest"
        (identityText === versionText <> "+" <> sourceDigest)
    , counterexample "a literal inside other bytes is found"
        (digestIn (Char8.pack ("\1\2PUDU-SOURCE-DIGEST:" <> hex <> ";\0tail")) === Just (Text.pack hex))
    , counterexample "a bare prefix is passed over for the literal after it"
        (digestIn (Char8.pack ("PUDU-SOURCE-DIGEST:xyzPUDU-SOURCE-DIGEST:" <> hex <> ";")) === Just (Text.pack hex))
    , counterexample "a short digest is not one"
        (digestIn (Char8.pack ("PUDU-SOURCE-DIGEST:" <> take 63 hex <> ";")) === Nothing)
    , counterexample "capitals are not the digest's spelling"
        (digestIn (Char8.pack ("PUDU-SOURCE-DIGEST:" <> map upper hex <> ";")) === Nothing)
    , counterexample "a digest with no terminator is not one"
        (digestIn (Char8.pack ("PUDU-SOURCE-DIGEST:" <> hex)) === Nothing)
    , counterexample "bytes with no literal carry nothing"
        (digestIn (Char8.pack "an ordinary executable") === Nothing)
    ]
 where
  hex = concat (replicate 4 "0123456789abcdef")
  upper c = if c >= 'a' && c <= 'f' then toEnum (fromEnum c - 32) else c
