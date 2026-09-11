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
  htmlServer <- runEntry "test-fixtures/stdlib/UsesHtmlServer.pudu"
  htmlBuild <- runEntry "test-fixtures/stdlib/UsesHtmlBuild.pudu"
  httpAll <- runEntry "test-fixtures/stdlib/UsesHttpAll.pudu"
  routeAll <- runEntry "test-fixtures/stdlib/UsesRouteAll.pudu"
  wireAll <- runEntry "test-fixtures/stdlib/UsesDbProtocolAll.pudu"
  cursorAll <- runEntry "test-fixtures/stdlib/UsesCursorAll.pudu"
  urlAll <- runEntry "test-fixtures/stdlib/UsesUrlAll.pudu"
  appDatabase <- runEntry "test-fixtures/stdlib/UsesAppDatabase.pudu"
  lookupTables <- runEntry "test-fixtures/stdlib/UsesLookupTables.pudu"
  printers <- runEntry "test-fixtures/stdlib/UsesOut.pudu"
  shaping <- runEntry "test-fixtures/stdlib/UsesFmt.pudu"
  byteSequences <- runEntry "test-fixtures/stdlib/UsesBytes.pudu"
  separated <- runEntry "test-fixtures/stdlib/UsesCsv.pudu"
  configured <- runEntry "test-fixtures/stdlib/UsesToml.pudu"
  scanned <- runEntry "test-fixtures/stdlib/UsesTomlScanAll.pudu"
  messaged <- runEntry "test-fixtures/stdlib/UsesHttpMessageReplyAll.pudu"
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
  yamlDocuments <- runEntry "test-fixtures/stdlib/UsesYaml.pudu"
  versionsAndGlobs <- runEntry "test-fixtures/stdlib/UsesSemverGlob.pudu"
  xmlDocuments <- runEntry "test-fixtures/stdlib/UsesXml.pudu"
  zipArchives <- runEntry "test-fixtures/stdlib/UsesArchiveZip.pudu"
  clientRetries <- runEntry "test-fixtures/stdlib/UsesHttpRetry.pudu"
  childProcesses <- runEntry "test-fixtures/stdlib/UsesProcessStream.pudu"
  exportedSpans <- runEntry "test-fixtures/stdlib/UsesOtlp.pudu"
  commandLines <- runEntry "test-fixtures/stdlib/UsesArgs.pudu"
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
        (shaping === Just "47")
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
        (serving === Just "36")
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
    {-| What a client is set up with is said through a bound naming the
        configuring trait alone, which is what checks those settings are usable
        as methods. The protection is checked at the port that decides it and
        at the call that overrides it, since which of the two wins decides
        whether the secret above it goes out in the clear. The two
        authentication mechanisms differ in the variant they hold and in
        nothing else, so each is read back: a client set up for one holding the
        other would send a proof the server did not ask for. -}
    , counterexample
        "SMTP client formats RFC 5321 commands, authenticates, parses replies, and rejects invalid states"
        (smtping === Just "21")
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
    {-| A deployment manifest of the shape one is really written in, because
        the parts that break a reader are the ones that only appear together:
        a sequence of mappings whose first key shares the dash's line, a
        sequence written level with its own key, and a block scalar whose
        lines must not be read as structure. The quoted `"3"` is the other
        half: a reader that decides kinds before it decides quoting turns a
        version string into a number. -}
    , counterexample
        "a manifest's mappings, sequences, block scalars, and quoting all survive"
        (yamlDocuments === Just "18")
    {-| The two orderings each have one case that a plausible implementation
        gets wrong and no ordinary use would reveal: `1.10.0` after `1.9.0`,
        which comparing as text reverses, and a `*` that stops at a separator,
        without which `src/*.pudu` and `src/**/*.pudu` name the same files and
        one of them cannot be written. -}
    , counterexample
        "versions order by number and globs stop at separators"
        (versionsAndGlobs === Just "24")
    {-| A SOAP envelope, because the parts that break a reader arrive together
        in one: a prefixed name, a self-closing element, an entity in text,
        and a CDATA section whose content must not be read as either. The
        refusals matter as much — a document type declaration is where a
        reader that skipped what it did not understand would read a file off
        the machine it is running on. -}
    , counterexample
        "an envelope's names, entities, and CDATA survive, and a DTD is refused"
        (xmlDocuments === Just "16")
    {-| A round trip proves the two halves agree; the size proves they agree
        about a real archive rather than about storing everything, which would
        also round-trip. That an archive written here is read by an ordinary
        zip tool, and one written by an ordinary zip tool is read here, is
        checked outside the language, where another implementation exists. -}
    , counterexample
        "an archive round-trips its entries and is actually compressed"
        (zipArchives === Just "12")
    {-| Which failures are retried, and which requests may be, are the two
        halves of the same question and the second is the one usually skipped:
        a POST retried after a timeout charges twice, and the timeout is
        exactly when a caller wants to retry. The jitter cases are here
        because backing off by a fixed doubling sends every caller back at the
        same moment, which is the failure a retry is supposed to prevent. -}
    , counterexample
        "a retry backs off, spreads out, and refuses to repeat what must not be repeated"
        (clientRetries === Just "15")
    {-| Two of these fail on an implementation that looks right. A deadline
        checked after reading the program's output waits for the program
        first, so the deadline bounds nothing; and a deadline waited on
        without reading stops any program that writes more than its pipe
        holds. The 120 KB case and the overrun case are each other's control.
        The pipeline through `yes` is the third: a first program that never
        ends on its own is only read from if both are running at once. -}
    , counterexample
        "a started program streams, honours a deadline, is stopped, and pipes into another"
        (childProcesses === Just "13")
    {-| The document is checked against the shape a collector requires rather
        than against itself, because a round trip through one writer and its
        own reader agrees however wrong both are. Two of these are about what
        is *not* sent: a span with no ending, which would be read as a
        measurement nothing measured, and a span the trace decided not to
        record. The settings are said through a bound naming the configuring
        trait alone, which is what checks they are usable as methods; a header
        is named twice to check that carrying adds rather than sets, since a
        key and a tenant set in two calls must both travel. Each reason an
        export failed is read for the sentence it gives, because a collector
        that answered is a different thing to debug from one that never did. -}
    , counterexample
        "finished spans render as the document a collector reads, and unfinished ones do not"
        (exportedSpans === Just "19")
    {-| Every form a person actually writes, because a reader that handles
        `--name value` and not `--name=value` is wrong for half of them. Two
        carry their own trap: `--` begins with a dash, so a reader dispatching
        on that reads the mark that ends the options as an option; and a lone
        `-` means standard input to nearly every program that takes a file, so
        reading it as an option takes that away. -}
    , counterexample
        "a command line's long, short, joined, clustered, and ended forms all read"
        (commandLines === Just "20")
    {-| A configuration file, in the shapes the format actually holds: every
        base a whole number is written in, a fractional one kept as its text
        rather than rounded into a binary float, sections and repeated
        sections, dotted keys, and a document written and read back. -}
    , counterexample
        "a configuration reads back what it was written as"
        (configured === Just "44")
    {-| Every export of the configuration scanner. Each reading call answers a
        value and where it stopped, and the position is checked beside the
        value every time: a reader answering the right text and the wrong
        position leaves the caller reading the same characters twice or
        skipping some, and nothing about the text alone would say so. The two
        kinds of quoted text are asked where they must differ — an apostrophe
        gives the format no escapes at all — and numbers are asked for a digit
        that is not one of the base they name, which is what separates reading
        a number from recognising that a word is one. -}
    , counterexample
        "every scan says where it stopped and a literal string keeps its backslash"
        (scanned === Just "83")
    {-| Every export of the message, reply and rendering modules. A message is
        written and read back from the same value, and the written text is also
        compared against what the protocol says, ending and all — a writer and
        a reader agreeing on a wrong spelling agree with each other and with no
        other implementation. A body shorter than the length declared for it is
        refused and a longer one accepted, since only the short case is how a
        truncated read shows itself. Every reply is checked for the length it
        declares as well as the body it carries, over a body carrying a
        character wider than one byte, where counting characters and counting
        bytes part company and a client reading the declared number stops in
        the middle. -}
    , counterexample
        "a message survives being written and read, and declares its body in bytes"
        (messaged === Just "93")
    {-| Every case here is a handshake that must fail. A handshake that
        wrongly succeeds carries traffic and looks exactly like one that did
        not, so failing closed is the only property worth checking offline. -}
    , counterexample
        "a secured connection refuses what it cannot prove"
        (secured === Just "7")
    , counterexample "the format modules parse and render"
        (formats === Just "8885")
    , counterexample "JSON strings decode, encode, and reject malformed escapes"
        (jsonStrings === Just "16")
    {-| Rendering a page from a plan prepared once and filled per request,
        including the case that is not a rendering fault but a way into the
        page: text carrying markup must arrive as the characters it is made
        of. -}
    , counterexample
        "a page rendered from a prepared plan, its holes, its limit, and its escaping"
        (htmlServer === Just "18")
    {-| Every export of the markup builder, checked against what it renders:
        each attribute against the attribute it sets, each tag against its own
        opening tag, and text against the escaping that keeps it text. -}
    , counterexample
        "every tag and attribute renders the markup it names"
        (htmlBuild === Just "97")
    {-| Every export of the protocol module against the wire form it stands
        for. The header names are checked against the spelling that goes on
        the wire, since a name answering the wrong header asks for something
        else and nothing else would notice; the status classes are checked at
        their boundaries, where a range written with the wrong comparison is
        wrong and nowhere else. -}
    , counterexample
        "every protocol name answers the wire form it stands for"
        (httpAll === Just "91")
    {-| Every export of the database wire module, each message checked against
        the wire rather than against the reader beside it: the letter it starts
        with, the length it states, and the bytes after that length. A writer
        and a reader that agreed on the same wrong shape would agree with each
        other and with nothing else, and a round trip is the one check that
        cannot tell them apart. The stated length is checked on every message
        because it is all a server has to go on — a byte short leaves a byte
        behind that the next read takes for a letter, and a byte long waits for
        one that never comes, and both look like a hang rather than like a
        malformed message. A value that is absent is checked against one that
        is empty, since the protocol spells them differently and a reader that
        treated them alike would answer nothing where the column holds the
        empty string. -}
    , counterexample
        "every database message states the length and the bytes the wire does"
        (wireAll === Just "70")
    {-| Every export of the routing module, checked by dispatching a request
        rather than by reading a route's fields, so what is checked is what a
        request actually reaches. A path written for another method answers
        that the method is not allowed rather than that the path is not there,
        and a caller told the wrong one of those retries forever or gives up
        wrongly. -}
    , counterexample
        "a request reaches the route written for its method, and no other"
        (routeAll === Just "35")
    {-| Every export of the cursor module, each read checked for the value and
        for the cursor that follows it. A reader answering the right number
        without moving on would pass a check that looked only at the value,
        and the next read would then answer the same bytes again. Each width
        is also asked past the end, which is the case a caller meets when the
        other end sent a short message. -}
    , counterexample
        "every read answers a value and the position after it"
        (cursorAll === Just "28")
    {-| Every export of the address module, with the parts read decoded and the
        rendering encoded again: a reader leaving `%20` as three characters and
        a writer leaving a space as a space each look right alone and together
        produce an address nothing can fetch. Both spellings of a space are
        read, since a plus is a space in a query and a plus in a path, and a
        decoder treating them alike turns one name into another silently. -}
    , counterexample
        "an address reads decoded, renders encoded, and survives the round trip"
        (urlAll === Just "48")
    {-| Preparing a database refuses what it can already see is wrong: a scheme
        nobody bundled, a pool that cannot hold a connection, a setting a
        deployment forgot. A program told at start-up can stop; the same
        program told at its first query, under load, cannot. -}
    , counterexample
        "a database prepared, and the connection strings and pool sizes it refuses"
        (appDatabase === Just "17")
    , counterexample "the protocol modules parse and render messages"
        (protocol === Just "266")
    , counterexample "dates, FASTA, FASTQ, quoted CSV, and delimited rows all parse"
        (realFormats === Just "16383")
    ]
