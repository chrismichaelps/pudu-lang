{-| @Test.Compiler.Program.Eval.ProtocolSpec — format, serialization, and wire protocol evaluation -}
module Pudu.Compiler.Program.Eval.ProtocolSpec
  ( testProtocolEvaluation
  ) where

import Pudu.Compiler.Program.Common (runEntry)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

{-| Evaluates formats, JSON, printers, CSV, TOML, HTTP, TLS, sockets, and network protocols. -}
testProtocolEvaluation :: IO Property
testProtocolEvaluation = do
  formats <- runEntry "test-fixtures/stdlib/UsesFormats.pudu"
  realFormats <- runEntry "test-fixtures/stdlib/UsesFormats2.pudu"
  jsonStrings <- runEntry "test-fixtures/stdlib/UsesJsonStrings.pudu"
  lookupTables <- runEntry "test-fixtures/stdlib/UsesLookupTables.pudu"
  printers <- runEntry "test-fixtures/stdlib/UsesOut.pudu"
  shaping <- runEntry "test-fixtures/stdlib/UsesFmt.pudu"
  byteSequences <- runEntry "test-fixtures/stdlib/UsesBytes.pudu"
  separated <- runEntry "test-fixtures/stdlib/UsesCsv.pudu"
  configured <- runEntry "test-fixtures/stdlib/UsesToml.pudu"
  protocol <- runEntry "test-fixtures/stdlib/UsesHttp.pudu"
  serving <- runEntry "test-fixtures/stdlib/UsesHttpServer.pudu"
  fetched <- runEntry "test-fixtures/stdlib/UsesHttpClient.pudu"
  secured <- runEntry "test-fixtures/stdlib/UsesTls.pudu"
  lasting <- runEntry "test-fixtures/stdlib/UsesSocket.pudu"
  endpoints <- runEntry "test-fixtures/stdlib/UsesNet.pudu"
  uploaded <- runEntry "test-fixtures/stdlib/UsesMultipart.pudu"
  posted <- runEntry "test-fixtures/stdlib/UsesMail.pudu"
  smtping <- runEntry "test-fixtures/stdlib/UsesSmtp.pudu"
  compressedGzip <- runEntry "test-fixtures/stdlib/UsesGzip.pudu"
  floatMath <- runEntry "test-fixtures/stdlib/UsesFloatMath.pudu"
  intMap <- runEntry "test-fixtures/stdlib/UsesIntMap.pudu"
  intSet <- runEntry "test-fixtures/stdlib/UsesIntSet.pudu"
  bloomFilter <- runEntry "test-fixtures/stdlib/UsesBloomFilter.pudu"
  diffOps <- runEntry "test-fixtures/stdlib/UsesDiff.pudu"
  mimeType <- runEntry "test-fixtures/stdlib/UsesMime.pudu"
  bitVector <- runEntry "test-fixtures/stdlib/UsesBitVector.pudu"
  fenwickTree <- runEntry "test-fixtures/stdlib/UsesFenwickTree.pudu"
  ringBuffer <- runEntry "test-fixtures/stdlib/UsesRingBuffer.pudu"
  varintCodec <- runEntry "test-fixtures/stdlib/UsesVarint.pudu"
  disjointSet <- runEntry "test-fixtures/stdlib/UsesDisjointSet.pudu"
  murmur3Hash <- runEntry "test-fixtures/stdlib/UsesMurmur3.pudu"
  rateLimiter <- runEntry "test-fixtures/stdlib/UsesRateLimiter.pudu"
  hexCodec <- runEntry "test-fixtures/stdlib/UsesHex.pudu"
  adler32Checksum <- runEntry "test-fixtures/stdlib/UsesAdler32.pudu"
  radixSort <- runEntry "test-fixtures/stdlib/UsesRadixSort.pudu"
  byteOrder <- runEntry "test-fixtures/stdlib/UsesByteOrder.pudu"
  sipHash <- runEntry "test-fixtures/stdlib/UsesSipHash.pudu"
  intervalTree <- runEntry "test-fixtures/stdlib/UsesIntervalTree.pudu"
  tarArchive <- runEntry "test-fixtures/stdlib/UsesArchiveTar.pudu"
  regexEngine <- runEntry "test-fixtures/stdlib/UsesRegex.pudu"
  stopSignals <- runEntry "test-fixtures/stdlib/UsesSignal.pudu"
  cryptoSurface <- runEntry "test-fixtures/stdlib/UsesCryptoSurface.pudu"
  providerTokens <- runEntry "test-fixtures/stdlib/UsesJwtKeys.pudu"
  pure $ conjoin
    [ {-| The five lookup tables at both ends and past the end, where a
          mistranscribed table would show. These held as nested if ladders and
          must hold as flat matches. -}
      counterexample
        "status reasons, methods, versions, hop-by-hop names, and scheme ports"
        (lookupTables === Just "23")
    {-| A printer's configuration, checked through its pure rendering rather
        than by capturing output: nothing to print, a piece that already spans
        lines, an indent on top of an indent, and an ending left empty so the
        line stays open. Each check answers 1. -}
    , counterexample
        "a printer carries its separator, ending, prefix, and stream"
        (printers === Just "35")
    {-| A spec's shaping, checked by comparing values rather than by looking at
        output. Weighted toward what a padding helper gets wrong: content wider
        than its width, a sign that must stay in front of zero padding, grouping
        that must not count the sign, and columns measured from the rows. -}
    , counterexample
        "a spec carries its width, fill, alignment, sign, and grouping"
        (shaping === Just "46")
    {-| A byte sequence answers for what it holds, and the two formats that
        travel as text answer against their own published vectors rather than
        against each other: a round trip through an encoder and its own decoder
        agrees with itself however wrong both halves are. -}
    , counterexample
        "bytes slice, search, and carry the published base64 and hex vectors"
        (byteSequences === Just "49")
    {-| The three things that make a separated file harder than splitting on
        the separator: a quoted field, a quote inside one, and a separator or
        newline that a quoted field swallows. -}
    , counterexample
        "a separated file survives quotes, newlines, and its own separator"
        (separated === Just "25")
    {-| A listener on the loopback address, a client, and a round trip, all in
        one program: the listener binds port zero and asks which port it was
        given, so nothing is assumed about what else the machine holds. -}
    , counterexample
        "a connection carries a message and the reply comes back"
        (endpoints === Just "14")
    {-| Routing, the chain of steps, and the method that carries its terms in
        its own body are checked by calling the handler directly; a request
        arriving and a reply going back are checked over a real socket. -}
    , counterexample
        "a server routes, wraps, and answers over a connection"
        (serving === Just "35")
    {-| That a client bounds what a request may cost and where it may go: an
        address the network trusts is refused unless the caller named it, and
        refused again at every redirect rather than only at the first, since a
        redirect to an internal address is how the first check is bypassed; a
        chain longer than the bound and an answer larger than the caller will
        read are refused rather than followed or truncated. -}
    , counterexample
        "a client is bounded in what it will fetch and where"
        (fetched === Just "45")
    {-| That a lasting connection is not offered to whoever asks: it is not
        subject to the rule stopping one site reading another's answers, so a
        page on any site could otherwise open one carrying the viewer's
        cookies. The origin is a parameter of the upgrade rather than a step
        that can be omitted. A message from the far end is refused unless
        masked, and how large one may be is checked against the length it
        states rather than against what arrived. The handshake is checked
        against the example the protocol itself publishes. -}
    , counterexample
        "a lasting connection is not offered to whoever asks"
        (lasting === Just "40")
    {-| That the name a sender gave a file never becomes a path: a file
        uploaded as an ascent has that as its name, and only what follows the
        last separator of either kind survives being asked for a name to write
        under — asked for, because a program reaching for a path should have to
        say so. Nothing is decoded before checking, since undoing an encoding
        first is how a check is bypassed, and every bound is applied while
        reading rather than once the memory is gone. -}
    , counterexample
        "an uploaded name never becomes a path"
        (uploaded === Just "44")
    {-| That a message cannot carry more than it says. A line break in an
        address or a subject would let whoever supplied it write headers of
        their own, which is how bulk mail is sent through somebody else's
        contact form; it is refused rather than stripped. Whoever is copied
        without the others knowing reaches the envelope and never the headers,
        so the disclosure nobody notices until afterwards has nothing that
        could produce it. A body line that would end the message is escaped. -}
    , counterexample
        "a message cannot carry more than it says"
        (posted === Just "46")
    , counterexample
        "SMTP client formats RFC 5321 commands, authenticates, parses replies, and rejects invalid states"
        (smtping === Just "16")
    , counterexample
        "GZIP compresses, streams multi-block DEFLATE, verifies CRC-32/ISIZE, and integrates HTTP middleware"
        (compressedGzip === Just "12")
    , counterexample
        "IEEE-754 trigonometry, exponentials, logarithms, roots, low-level binary GCD, and edge cases"
        (floatMath === Just "20")
    , counterexample
        "IntMap Patricia Trie inserts, queries, deletes, unions, differences, sorts, and signed/boundary edge cases"
        (intMap === Just "17")
    , counterexample
        "IntSet Patricia Trie inserts, deletes, unions, intersections, differences, subsets, splits, and signed edge cases"
        (intSet === Just "20")
    , counterexample
        "BloomFilter creates, optimally sizes, guarantees zero false negatives, merges, intersects, and estimates count"
        (bloomFilter === Just "10")
    , counterexample
        "Diff Myers O(ND) line/token differences, unified diff headers and hunks, and Levenshtein metrics"
        (diffOps === Just "10")
    , counterexample
        "Mime parses media types, parameters, 60+ extensions, and negotiates HTTP Accept headers"
        (mimeType === Just "10")
    , counterexample
        "BitVector dense 64-bit word packed bitwise AND/OR/XOR/NOT, popcount, and trailing-zero scan"
        (bitVector === Just "10")
    , counterexample
        "FenwickTree O(log n) prefix sums, point updates, range sum queries, and binary lifting search"
        (fenwickTree === Just "10")
    , counterexample
        "RingBuffer power-of-two bounded circular FIFO queue with branchless bitmask wrapping"
        (ringBuffer === Just "10")
    , counterexample
        "Varint ULEB128 and signed ZigZag SLEB128 variable-length integer encoding and decoding"
        (varintCodec === Just "10")
    , counterexample
        "DisjointSet flat array Union-Find with iterative path halving and union-by-rank"
        (disjointSet === Just "10")
    , counterexample
        "Murmur3 hardware-oriented 32-bit hash with word rotations and bit avalanche"
        (murmur3Hash === Just "10")
    , counterexample
        "RateLimiter 64-bit fixed-point integer token bucket traffic shaper"
        (rateLimiter === Just "10")
    , counterexample
        "Hex low-level Base16 encoder, decoder, validator, and prefix handler"
        (hexCodec === Just "10")
    , counterexample
        "Adler32 RFC 1950 unrolled checksum with 5552-byte blocks and O(1) rolling hash"
        (adler32Checksum === Just "10")
    , counterexample
        "RadixSort linear-time O(N) hardware radix sort for 64-bit integers"
        (radixSort === Just "10")
    , counterexample
        "ByteOrder endian conversions, network byte order, and buffer codecs"
        (byteOrder === Just "10")
    , counterexample
        "SipHash-2-4 cryptographic-strength short-input PRF with 64-bit word rotations"
        (sipHash === Just "10")
    , counterexample
        "IntervalTree augmented 1D interval tree with O(log n + k) stabbing queries"
        (intervalTree === Just "10")
    {-| A whole archive written and read back, because the two halves are only
        correct together: a header field written at the wrong offset reads back
        at the same wrong offset, and a round trip through one implementation
        agrees with itself. What is checked against the format rather than
        against the writer is the block size, the two-block ending, and the
        padding that a body shorter or longer than a block must get. -}
    , counterexample
        "a USTAR archive round-trips entries, sizes, directories, and padding"
        (tarArchive === Just "13")
    {-| Each piece of pattern syntax against a subject that distinguishes it
        from the piece next to it: greedy against lazy on the same subject, a
        group that took part against one that did not, a bound that is met
        against one that is exceeded. The last case is the one a server
        depends on — a pattern whose search would take exponential time gives
        up and says so rather than running. -}
    , counterexample
        "patterns compile, match, capture, replace, and refuse to run away"
        (regexEngine === Just "24")
    {-| What can be checked from inside one process: that the platform can hear
        a request to stop, and that a program nobody has asked to stop says so.
        Whether an actual signal reaches a running program is checked by
        `test/signal-drain.mjs`, which needs two processes to ask. -}
    , counterexample
        "a program can hear a request to stop, and knows it has not had one"
        (stopSignals === Just "5")
    {-| The keyed digest and the digest are checked against their own published
        vectors rather than against each other, because two halves of one
        wrong implementation agree perfectly. Sealing is checked the other way
        — by what must fail: the wrong key, a changed byte, and context that
        does not match must each answer nothing, since a sealed message that
        opens under any of them is not sealed. -}
    , counterexample
        "keyed digests match their vectors, and a sealed message refuses to open wrongly"
        (cryptoSurface === Just "14")
    {-| The tokens were signed elsewhere, by a private key the fixture does not
        hold, so verifying them is a property nothing in the fixture could have
        arranged. The case that matters most is the one where the header lies
        about its algorithm: a token checked with the algorithm it names rather
        than the one its key uses lets a public key be presented as a shared
        secret, and every token then verifies. -}
    , counterexample
        "a provider's tokens verify, and a token that lies about its algorithm does not"
        (providerTokens === Just "10")
    {-| A configuration file, in the shapes the format actually holds: every
        base a whole number is written in, a fractional one kept as its text
        rather than rounded into a binary float, sections and repeated
        sections, dotted keys, and a document written and read back. -}
    , counterexample
        "a configuration reads back what it was written as"
        (configured === Just "44")
    {-| Every case here is a handshake that must fail. A handshake that
        wrongly succeeds carries traffic and looks exactly like one that did
        not, so failing closed is the only property worth checking offline. -}
    , counterexample
        "a secured connection refuses what it cannot prove"
        (secured === Just "7")
    , counterexample "the format modules parse and render"
        (formats === Just "8885")
    , counterexample "JSON strings decode, encode, and reject malformed escapes"
        (jsonStrings === Just "0")
    , counterexample "the protocol modules parse and render messages"
        (protocol === Just "266")
    , counterexample "dates, FASTA, FASTQ, quoted CSV, and delimited rows all parse"
        (realFormats === Just "16383")
    ]
