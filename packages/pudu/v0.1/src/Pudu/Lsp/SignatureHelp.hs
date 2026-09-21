{-| @Program.Lsp.SignatureHelp — active signature and parameter assistance

    The signature is the type the checker gave the callee. That one answer
    covers a function the file declares, one it imports, a method of a
    built-in type, a method an `impl` provides, and a function held in a
    binding, because the checker has already worked out which of those the
    callee is. The documentation index adds what the type cannot say: the
    parameters' names, when the file declares the function, and its comment. -}
module Pudu.Lsp.SignatureHelp (signatureHelpAt, signatureHelpRepaired) where

import Data.Char (isAlphaNum, isSpace)
import Data.Maybe (isJust)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Doc (DocEntry (..), DocIndex (..), DocKind (..))
import Pudu.Doc.Signature (Signature (..), renderSigType, renderSignature)
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.Repair (Repair (..), closedPrefix, lineBounds, mostComplete, withoutRange)
import Pudu.Type (narrowestAt, renderType)
import Pudu.Type.Value (Type (..))

{-| Where a call is being written: the callee's name, where that name ends,
    and how many arguments precede the cursor. -}
data Call = Call
  { callName :: !Text
  , callNameEnd :: !Int
  , callArgument :: !Int
  }

signatureHelpAt :: Analysis -> Int -> Json
signatureHelpAt value = signatureHelpFrom value value

{-| Signature help for a call whose parenthesis is still open.

    `area(width, ` does not parse, so the program as written has no types at
    all. The call is read from the written text, and its signature from the
    program with the call closed at the cursor or, failing that, without the
    line being written. -}
signatureHelpRepaired :: (Text -> IO Analysis) -> Analysis -> Int -> IO Json
signatureHelpRepaired analyse value offset = case findCall content offset of
  Nothing -> pure JsonNull
  Just call
    | isJust (calleeType value call) -> pure (signatureHelpAt value offset)
    | otherwise -> do
        (known, _) <-
          mostComplete analyse (\known -> isJust (calleeType known call)) value offset
            [ Repair (Text.take offset content <> ")" <> Text.drop offset content) offset
            , withoutRange content lineStart lineEnd
            , closedPrefix (analysisTokens value) content offset
            ]
        pure (signatureHelpFrom value known offset)
 where
  content = analysisText value
  (lineStart, lineEnd) = lineBounds content offset

signatureHelpFrom :: Analysis -> Analysis -> Int -> Json
signatureHelpFrom written known offset = case findCall (analysisText written) offset of
  Nothing -> JsonNull
  Just call -> case calleeType known call of
    Just (inputs, result) -> answer call (fromType known call inputs result)
    Nothing -> maybe JsonNull (answer call) (fromDocs known call)

{-| The function type the checker gave the callee, when it gave one. -}
calleeType :: Analysis -> Call -> Maybe ([Type], Type)
calleeType value call = do
  found <- analysisTypes value >>= narrowestAt (callNameEnd call - 1)
  functionShape found
 where
  functionShape typeValue = case typeValue of
    FunctionTypeValue _ inputs result -> Just (inputs, result)
    RestrictedType _ inner -> functionShape inner
    ReferenceTypeValue _ inner -> functionShape inner
    _ -> Nothing

{-| One signature as shown: its label, and each parameter's range within it. -}
data Shown = Shown
  { shownLabel :: !Text
  , shownParameters :: ![(Int, Int)]
  , shownDocumentation :: ![Text]
  }

fromType :: Analysis -> Call -> [Type] -> Type -> Shown
fromType value call inputs result =
  let entry = declared value (callName call)
      names = maybe [] (parameterNames value (length inputs)) entry
      pieces = zipWith written (map Just names <> repeat Nothing) (map renderType inputs)
      written name rendered = maybe rendered (\given -> given <> ": " <> rendered) name
   in laidOut (callName call) pieces (renderType result) (maybe [] docComment entry)

fromDocs :: Analysis -> Call -> Maybe Shown
fromDocs value call = do
  entry <- declared value (callName call)
  sig <- docSignature entry
  let arguments = map renderSigType (signatureArguments sig)
      names = parameterNames value (length arguments) entry
      pieces = zipWith (\name rendered -> maybe rendered (<> (": " <> rendered)) name) (map Just names <> repeat Nothing) arguments
  pure
    ( if null arguments
        then Shown (docName entry <> ": " <> renderSignature sig) [] (docComment entry)
        else laidOut (docName entry) pieces (renderSigType (signatureResult sig)) (docComment entry)
    )

{-| `name(first, second) -> result`, with the range of each parameter. -}
laidOut :: Text -> [Text] -> Text -> [Text] -> Shown
laidOut name pieces result =
  Shown (name <> "(" <> Text.intercalate ", " pieces <> ") -> " <> result) (ranges (Text.length name + 1) pieces)
 where
  ranges _ [] = []
  ranges from (piece : rest) = (from, from + Text.length piece) : ranges (from + Text.length piece + 2) rest

answer :: Call -> Shown -> Json
answer call shown =
  let parameters = shownParameters shown
      active = min (callArgument call) (max 0 (length parameters - 1))
   in JsonObject
        [ ( "signatures"
          , JsonArray
              [ JsonObject
                  [ ("label", JsonText (shownLabel shown))
                  , ( "documentation"
                    , JsonObject
                        [ ("kind", JsonText "markdown")
                        , ("value", JsonText (Text.intercalate "\n" (shownDocumentation shown)))
                        ]
                    )
                  , ( "parameters"
                    , JsonArray
                        [ JsonObject [("label", JsonArray [JsonNumber (fromIntegral from), JsonNumber (fromIntegral to)])]
                        | (from, to) <- parameters
                        ]
                    )
                  ]
              ]
          )
        , ("activeSignature", JsonNumber 0)
        , ("activeParameter", JsonNumber (fromIntegral active))
        ]

{-| The documented function of that name, the file's own before a
    dependency's, so a local function is found before an imported one. -}
declared :: Analysis -> Text -> Maybe DocEntry
declared value name =
  case [entry | entry <- entries, docName entry == name, callable (docKind entry)] of
    entry : _ -> Just entry
    [] -> Nothing
 where
  entries = indexEntries (analysisFileIndex value) <> indexEntries (analysisProgramIndex value)
  callable kind = case kind of
    DocType -> False
    DocTrait -> False
    DocConstant -> False
    _ -> True

{-| The parameter names a declaration in this file writes, when there are as
    many as the call takes. A method's `self` is not one of the call's. -}
parameterNames :: Analysis -> Int -> DocEntry -> [Text]
parameterNames value count entry
  | not (isFileEntry value entry) = []
  | otherwise =
      let (start, end) = docSpan entry
          declaration = Text.take (end - start) (Text.drop start (analysisText value))
          afterName = Text.drop 1 (Text.dropWhile (/= '(') declaration)
          names = map nameOf (splitTopLevel (closedBody afterName))
          withoutSelf = case names of
            "self" : rest -> rest
            _ -> names
       in if length withoutSelf == count && all (not . Text.null) withoutSelf then withoutSelf else []
 where
  nameOf piece = let name = Text.strip (Text.takeWhile (/= ':') piece) in if Text.all isNameScalar name then name else ""

isFileEntry :: Analysis -> DocEntry -> Bool
isFileEntry value entry = entry `elem` indexEntries (analysisFileIndex value)

{-| The text up to the parenthesis that closes the one already opened. -}
closedBody :: Text -> Text
closedBody = Text.pack . go (0 :: Int) . Text.unpack
 where
  go _ [] = []
  go depth (scalar : rest)
    | scalar == ')' && depth == 0 = []
    | scalar `elem` ("([{" :: String) = scalar : go (depth + 1) rest
    | scalar `elem` (")]}" :: String) = scalar : go (depth - 1) rest
    | otherwise = scalar : go depth rest

splitTopLevel :: Text -> [Text]
splitTopLevel = filter (not . Text.all isSpace) . map Text.pack . go (0 :: Int) [] . Text.unpack
 where
  go _ current [] = [reverse current]
  go depth current (scalar : rest)
    | scalar == ',' && depth == 0 = reverse current : go depth [] rest
    | scalar `elem` ("([{<" :: String) = go (depth + 1) (scalar : current) rest
    | scalar `elem` (")]}>" :: String) = go (max 0 (depth - 1)) (scalar : current) rest
    | otherwise = go depth (scalar : current) rest

isNameScalar :: Char -> Bool
isNameScalar scalar = isAlphaNum scalar || scalar == '_'

{-| The call the cursor is inside: the nearest parenthesis before it that is
    not closed before it, and the name written just before that parenthesis. -}
findCall :: Text -> Int -> Maybe Call
findCall content offset = do
  let before = Text.take offset content
  (arguments, opened) <- scan (0 :: Int) (0 :: Int) (Text.length before - 1) (reverse (Text.unpack before))
  let trimmed = Text.dropWhileEnd isSpace (Text.take opened before)
      name = Text.takeWhileEnd isNameScalar trimmed
  if Text.null name then Nothing else Just (Call name (Text.length trimmed) arguments)
 where
  scan _ _ _ [] = Nothing
  scan depth commas index (scalar : rest) = case scalar of
    ')' -> scan (depth + 1) commas (index - 1) rest
    '('
      | depth == 0 -> Just (commas, index)
      | otherwise -> scan (depth - 1) commas (index - 1) rest
    ',' | depth == 0 -> scan depth (commas + 1) (index - 1) rest
    _ -> scan depth commas (index - 1) rest
