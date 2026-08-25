module Pudu.DocSpec (docProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Doc
  ( DocEntry (..)
  , DocIndex (..)
  , entriesFor
  )
import Pudu.Doc.Json (encodeIndex, escapeJson)
import Pudu.Doc.Query (Query (..), parseQuery)
import Pudu.Doc.Search (Match (..), searchText)
import Pudu.Doc.Signature (renderSignature)
import Pudu.Source (SourceName (SourceName), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

docProperties :: [(String, IO Property)]
docProperties =
  [ ("the index reports the type the checker inferred", testInferredSignatures)
  , ("doc comments attach to the declaration they precede", testDocComments)
  , ("a type query finds a function by its shape", testTypeSearch)
  , ("a name query ranks exact matches first", testNameSearch)
  , ("queries are read as names or as shapes", testQueryParsing)
  , ("the encoded index is well formed", testEncoding)
  ]

{-| The whole point of building the index from the checker: a declaration with
    no written types is still described, and one with written types is described
    as the compiler understood it. -}
testInferredSignatures :: IO Property
testInferredSignatures = do
  index <- indexOf
    [ "module Doc"
    , "fn twice(n: Int) -> Int { n * 2 }"
    , "fn inferred(n) { n + 1 }"
    , "fn pick[T](left: T, right: T) -> T { left }"
    , "const LIMIT: Int = 5"
    ]
  pure $ conjoin
    [ counterexample "an annotated function reports its type"
        (signatureOf "twice" index === "Int -> Int")
    , counterexample "an unannotated function reports its inferred type"
        (signatureOf "inferred" index === "Int -> Int")
    , counterexample "a generic function keeps its parameter and bound"
        (signatureOf "pick" index === "T -> T -> T")
    , counterexample "a constant reports its type with no arguments"
        (signatureOf "LIMIT" index === "Int")
    ]

{-| Documentation is the run of `///` lines directly above a declaration, and
    an ordinary comment is not documentation. -}
testDocComments :: IO Property
testDocComments = do
  index <- indexOf
    [ "module Doc"
    , "/// Double a number."
    , "/// The second line is kept."
    , "fn twice(n: Int) -> Int { n * 2 }"
    , "// an ordinary note"
    , "fn plain(n: Int) -> Int { n }"
    , "/// Documented and exported."
    , "export fn shown(n: Int) -> Int { n }"
    , "/** A block form. */"
    , "fn blocked(n: Int) -> Int { n }"
    ]
  pure $ conjoin
    [ counterexample "every doc line is kept in order"
        (commentOf "twice" index === ["Double a number.", "The second line is kept."])
    , counterexample "an ordinary comment is not documentation"
        (commentOf "plain" index === [])
    , counterexample "a block doc comment is documentation"
        (commentOf "blocked" index === ["A block form."])
    , counterexample "an export modifier does not detach the documentation"
        (commentOf "shown" index === ["Documented and exported."])
    ]

{-| Search by shape, which is the question a reader with a type but no name
    is asking. -}
testTypeSearch :: IO Property
testTypeSearch = do
  index <- indexOf
    [ "module Doc"
    , "fn first[T](items: Array[T]) -> T { items[0] }"
    , "fn twice(n: Int) -> Int { n * 2 }"
    , "fn label(n: Int) -> Str { \"n\" }"
    ]
  pure $ conjoin
    [ counterexample "a polymorphic shape finds the polymorphic function"
        (namesOf (searchText "Array[a] -> a" index) === ["first"])
    , counterexample "a concrete shape finds the concrete function"
        (namesOf (searchText "Int -> Int" index) === ["twice"])
    , counterexample "a shape nothing has finds nothing"
        (namesOf (searchText "Str -> Str" index) === [])
    , counterexample "a variable query does not match a concrete signature exactly"
        (notElem "twice" (namesOf (searchText "a -> a" index)) === True)
    ]

{-| A name query ranks the closest spelling first, so a reader who typed most
    of a name gets it before everything that merely contains it. -}
testNameSearch :: IO Property
testNameSearch = do
  index <- indexOf
    [ "module Doc"
    , "fn sort(n: Int) -> Int { n }"
    , "fn sortBy(n: Int) -> Int { n }"
    , "fn resort(n: Int) -> Int { n }"
    ]
  pure $ conjoin
    [ counterexample "an exact name comes first"
        (take 1 (namesOf (searchText "sort" index)) === ["sort"])
    , counterexample "a prefix outranks an infix"
        (namesOf (searchText "sort" index) === ["sort", "sortBy", "resort"])
    ]

{-| The one disambiguation rule the query language has. -}
testQueryParsing :: IO Property
testQueryParsing =
  pure $ conjoin
    [ counterexample "a bare word is a name" (isName (parseQuery "sort") === True)
    , counterexample "an applied type with no arrow is still a name"
        (isName (parseQuery "Array[Int]") === True)
    , counterexample "an arrow makes it a shape" (isShape (parseQuery "Int -> Int") === True)
    , counterexample "blank input is no query" (parseQuery "   " === Nothing)
    , counterexample "a nested arrow stays inside its argument"
        (renderedQuery (parseQuery "(fn(Int) -> Str) -> Bool") === Just "fn(Int) -> Str -> Bool")
    ]
 where
  isName query = case query of
    Just (NameQuery _) -> True
    _ -> False
  isShape query = case query of
    Just (TypeQuery _) -> True
    _ -> False
  renderedQuery query = case query of
    Just (TypeQuery signature) -> Just (renderSignature signature)
    _ -> Nothing

{-| The encoding is a contract with editors, so its escaping has to hold for
    text a reader can actually write. -}
testEncoding :: IO Property
testEncoding = do
  index <- indexOf
    [ "module Doc"
    , "/// A \"quoted\" note."
    , "fn twice(n: Int) -> Int { n * 2 }"
    ]
  let encoded = encodeIndex index
  pure $ conjoin
    [ counterexample "quotes are escaped" (escapeJson "a\"b" === "a\\\"b")
    , counterexample "backslashes are escaped" (escapeJson "a\\b" === "a\\\\b")
    , counterexample "newlines are escaped" (escapeJson "a\nb" === "a\\nb")
    , counterexample "the entry survives encoding"
        (property (Text.isInfixOf "\\\"quoted\\\"" encoded))
    , counterexample "the signature is carried alongside the structure"
        (property (Text.isInfixOf "\"form\":\"con\"" encoded))
    ]

indexOf :: [Text] -> IO DocIndex
indexOf lines' = do
  source <- newSource (SourceName "Doc.pudu") (Text.unlines lines')
  maybe (DocIndex []) id . compileDocs <$> runCompile source

signatureOf :: Text -> DocIndex -> Text
signatureOf name index = case entriesFor name index of
  entry : _ -> maybe "none" renderSignature (docSignature entry)
  [] -> "missing"

commentOf :: Text -> DocIndex -> [Text]
commentOf name index = case entriesFor name index of
  entry : _ -> docComment entry
  [] -> ["missing"]

namesOf :: [Match] -> [Text]
namesOf = map (docName . matchEntry)
