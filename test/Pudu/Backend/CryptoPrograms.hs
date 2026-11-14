{-| @Test.Backend.CryptoPrograms — digests, keyed digests, derived keys, checksums, sealing and audio generators; expected output checked against hashlib, zlib and RFC 8439 vectors. -}
module Pudu.Backend.CryptoPrograms (cryptoSuccessPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

cryptoSuccessPrograms :: [(String, Text, Text)]
cryptoSuccessPrograms =
  [ ( "digests, keyed digests, derived keys, checksums, sealing and audio generators"
      , program
        [ "fn main() -> Int {"
        , "  let empty = bytesOf([])"
        , "  let abc = \"abc\".toBytes()"
        , "  let long = \"The quick brown fox jumps over the lazy dog, again and again, until the block boundary is well behind us at last.\".toBytes()"
        , "  print(show(sha256Of(empty)) + show(sha256Of(abc)) + show(sha256Of(long)))"
        , "  print(show(sha512Of(empty)) + show(sha512Of(abc)) + show(sha512Of(long)))"
        , "  print(show(sha3_256Of(empty)) + show(sha3_256Of(abc)) + show(sha3_256Of(long)))"
        , "  print(show(sha3_512Of(empty)) + show(sha3_512Of(abc)) + show(sha3_512Of(long)))"
        , "  print(show(blake2b256Of(empty)) + show(blake2b256Of(abc)) + show(blake2b256Of(long)))"
        , "  print(show(blake2b512Of(empty)) + show(blake2b512Of(abc)) + show(blake2b512Of(long.concat(long))))"
        , "  print(show(hmacSha256Of(abc, long)) + show(hmacSha256Of(long.concat(long), abc)) + show(hmacSha256Of(empty, empty)))"
        , "  print(show(hmacSha512Of(abc, long)) + show(hmacSha512Of(long.concat(long), abc)) + show(hmacSha512Of(empty, empty)))"
        , "  print(show(deriveKey(\"password\".toBytes(), \"salt\".toBytes(), 1, 32)) + show(deriveKey(\"password\".toBytes(), \"salt\".toBytes(), 4096, 20)) + show(deriveKey(empty, empty, 2, 70)))"
        , "  print(display(constantTimeEqual(abc, \"abc\".toBytes())) + display(constantTimeEqual(abc, long)) + display(constantTimeEqual(abc, \"abd\".toBytes())) + display(constantTimeEqual(empty, empty)))"
        , "  print(display(checksumOf(0, 0u64, \"123456789\".toBytes())) + \" \" + display(checksumOf(1, 0u64, \"123456789\".toBytes())) + \" \" + display(checksumOf(2, 0u64, \"123456789\".toBytes())) + \" \" + display(checksumOf(3, 2166136261u64, abc)) + \" \" + display(checksumOf(4, 14695981039346656037u64, abc)) + \" \" + display(checksumOf(0, checksumOf(0, 0u64, \"1234\".toBytes()), \"56789\".toBytes())) + \" \" + display(checksumOf(0, 18446744073709551615u64, abc)))"
        , "  let key = sha256Of(\"key\".toBytes())"
        , "  let nonce = bytesOf([7u8, 0u8, 0u8, 0u8, 64u8, 65u8, 66u8, 67u8, 68u8, 69u8, 70u8, 71u8])"
        , "  let sealed = sealBytes(key, nonce, long, abc)"
        , "  print(show(sealed) + show(sealBytes(abc, nonce, long, abc)) + show(sealBytes(key, abc, long, abc)) + show(sealBytes(key, nonce, empty, empty)))"
        , "  match sealed {"
        , "    case Some(box) => {"
        , "      print(show(openSealedBytes(key, nonce, box, abc)) + show(openSealedBytes(key, nonce, box, empty)) + show(openSealedBytes(key, nonce, box.slice(1, box.length()), abc)) + show(openSealedBytes(key, nonce, abc, abc)) + show(openSealedBytes(abc, nonce, box, abc)))"
        , "    }"
        , "    case None => print(\"none\")"
        , "  }"
        , "  print(show(audioToneBytes(0, 4, 1000, 1, 0, 6)) + show(audioToneBytes(1, 5, 32767, 2, 3, 6)) + show(audioToneBytes(2, 7, 12000, 1, 9223372036854775800, 9)) + show(audioToneBytes(3, 4, 1, 1, 0, 1)) + show(audioToneBytes(0, 1, 1, 1, 0, 1)) + show(audioToneBytes(0, 4, 32768, 1, 0, 1)) + show(audioToneBytes(0, 4, 1, 9, 0, 1)) + show(audioToneBytes(0, 4, 1, 1, -1, 1)) + show(audioToneBytes(0, 4, 1, 1, 0, 4097)) + show(audioToneBytes(2, 9223372036854775807, 32767, 1, 9223372036854775000, 3)))"
        , "  let pcm = bytesOf([0u8, 64u8, 0u8, 192u8, 255u8, 127u8, 0u8, 128u8, 1u8, 0u8, 255u8, 255u8])"
        , "  print(show(audioRampBytes(pcm, 1, 0, 1, 32768, 5, 0)) + show(audioRampBytes(pcm, 2, 10, 10, 0, 12, 131072)) + show(audioRampBytes(pcm, 1, 0, 0, 131072, 1, 131072)) + show(audioRampBytes(pcm, 4, 0, 0, 1, 2, 1)) + show(audioRampBytes(pcm, 1, 0, 3, 1, 3, 1)) + show(audioRampBytes(pcm, 1, 0, 0, 131073, 1, 1)) + show(audioRampBytes(pcm, 1, 9223372036854775800, 0, 100, 9223372036854775807, 70000)))"
        , "  let digest = sha256Of"
        , "  let seal = sealBytes"
        , "  let tone = audioToneBytes"
        , "  let sum = checksumOf"
        , "  print(show(digest) + show(digest(abc)) + show(seal(key, nonce, abc, abc)) + show(tone(0, 2, 5, 1, 0, 2)) + display(sum(0, 0u64, abc)))"
        , "  0"
        , "}"
        ]
      , "0xe3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8550xba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad0x839d6e7bdb764e2048a2cc0daa902a54b01338ef92988018d103238e0adb1e76\n0xcf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e0xddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f0x914fb116861a48e8dbc0d6e6a8ac5e7fb4984cf51640e1ef2551057e0454872b2693a2634ac7e6e0710e2185dc770cb2b9cd0f4a9e342702bbaad6a7c141c72e\n0xa7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a0x3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe245114315320xdb48e12209ac963c1b3c6782c2f025e4f1db1906d3d64ff63fb07d9e67a52a53\n0xa69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a615b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd260xb751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f00x63f15b676cdf4668b4822f191005e5103358a2764c6c804ef4ec153155657abfa31bae91a0d504e188d3ed206dd334b545be046f8f30f59dff013f3fb37a3f0b\n0x0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a80xbddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d523190x0eb242640932c6be46033b4a774f41463a668ec007298a50b6f3e6ee3c404f4f\n0x786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce0xba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd40099230xd99e934a8fd5a30bedd5b42a2ed1d3c9669ab26c8dc8b1cc79304325930b43339aeaf62c9cc1516e4bb83a009196d73a164ec191dd3949a1552c6b8abfb1044a\n0x9ec14807032897162f133c4cd92a7b70fdd4040cd6be0e86fd90d12cb7f6c3d30xe7c8e23f98acee992c048da2d19da34b06d31f66586c6e6e870e129180a808f30xb613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad\n0xe8c93db3f8bf93978a75cacc30f3ba28ba0096581785797596eb67405647461b6374ad30bb1126bbd67361c0734d010d1123fd4055b05e83b1ef1787552a7f480xd3e9981995fb7268e6030b6189ce5117a39f984fd0988b5c13f64d6a08cebd3305628714c0f6e14ca283c8c0b800241a8e64ce6275c9902175d89b9a1822fb5f0xb936cee86c9f87aa5d3c6f2e84cb5a4239a5fe50480a6ec66b70ab5b1f4ac6730c6c515421b327ec1d69402e53dfb49ad7381eb067b338fd7b0cb22247225d47\n0x120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b0xc5e478d59288c841aa530db6845c4c8d962893a00x97398411d6aea43a77acef92226ab8278d4db0668bd1d7a76a725f7680ac45c504d715e13d3c31a6c1539b9713ea6916da72027e1b2f37962f8bf0306ae25840982bedced4ff\ntruefalsefalsetrue\n3421780262 3808858755 11051210869376104954 440920331 16654208175385433931 3421780262 899311407\nSome(0x00b51e47d545634640414404b83e842326b2314ef05d1e2d61f61c196ebdb189925c4c4589d0f17fd15013c2c080e5341af356a057261318e04e9c25f29e4784c040eec9f1502565f8891641509b8075f3682c0e32d8c0db6797120038c51a7c367d3efa7234a987b4246b78eea131f41a74fe455f60129e8e1f9aef257eedd362)NoneNoneSome(0x2bb1d55d84514c6159f8eaea53917f4b)\nSome(0x54686520717569636b2062726f776e20666f78206a756d7073206f76657220746865206c617a7920646f672c20616761696e20616e6420616761696e2c20756e74696c2074686520626c6f636b20626f756e646172792069732077656c6c20626568696e64207573206174206c6173742e)NoneNoneNoneNone\nSome(0xe803e80318fc18fce803e803)Some(0x99199919cc4ccc4c0180018033b333b366e666e699199919)Some(0x20d160f0a00fe02e7017000090e820d160f0)NoneNoneNoneNoneNoneNoneSome(0x028002800280)\nSome(0x004000c0ff5f00c000000000)Some(0x00000000ff7f00800400fcff)Some(0xff7f0080ff7f00800400fcff)NoneNoneNoneSome(0xff7f0080ff7f00800200feff)\n<builtin sha256Of>0xba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015adSome(0x35bf188e0cc4723538a4307c533618276d9ead)Some(0x0500fbff)891568578\n" )
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
