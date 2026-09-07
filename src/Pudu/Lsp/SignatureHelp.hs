{-| @Program.Lsp.SignatureHelp — active signature and parameter assistance -}
module Pudu.Lsp.SignatureHelp (signatureHelpAt) where

import Data.Char (isAlphaNum)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Doc (DocEntry (..), DocIndex (..))
import Pudu.Doc.Signature (Signature (..), renderSigType, renderSignature)
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Json (Json (..))

signatureHelpAt :: Analysis -> Int -> Json
signatureHelpAt value offset =
  case findCallContext (analysisText value) offset of
    Nothing -> JsonNull
    Just (callee, commaCount) ->
      case findDocEntry (analysisProgramIndex value) callee of
        Nothing -> JsonNull
        Just entry -> case docSignature entry of
          Nothing -> JsonNull
          Just sig ->
            let params =
                  [ JsonObject [("label", JsonText (renderSigType arg))]
                  | arg <- signatureArguments sig
                  ]
                activeParam = min commaCount (max 0 (length params - 1))
                info =
                  JsonObject
                    [ ("label", JsonText (docName entry <> ": " <> renderSignature sig))
                    , ( "documentation"
                      , JsonObject
                          [ ("kind", JsonText "markdown")
                          , ("value", JsonText (Text.intercalate "\n" (docComment entry)))
                          ]
                      )
                    , ("parameters", JsonArray params)
                    ]
             in JsonObject
                  [ ("signatures", JsonArray [info])
                  , ("activeSignature", JsonNumber 0)
                  , ("activeParameter", JsonNumber (fromIntegral activeParam))
                  ]

findDocEntry :: DocIndex -> Text -> Maybe DocEntry
findDocEntry index name =
  case [entry | entry <- indexEntries index, docName entry == name] of
    entry : _ -> Just entry
    [] -> Nothing

findCallContext :: Text -> Int -> Maybe (Text, Int)
findCallContext content offset =
  let before = Text.take offset content
   in case scanParen 0 0 (reverse (Text.unpack before)) of
        Just (commas, rest) ->
          let calleeText = Text.pack (reverse (takeWhile isNameChar (dropWhile (== ' ') rest)))
           in if Text.null calleeText then Nothing else Just (calleeText, commas)
        Nothing -> Nothing
 where
  isNameChar c = isAlphaNum c || c == '_'

scanParen :: Int -> Int -> [Char] -> Maybe (Int, [Char])
scanParen _ _ [] = Nothing
scanParen depth commas (c : rest)
  | c == ')' = scanParen (depth + 1) commas rest
  | c == '(' =
      if depth == 0
        then Just (commas, rest)
        else scanParen (depth - 1) commas rest
  | c == ',' && depth == 0 = scanParen depth (commas + 1) rest
  | otherwise = scanParen depth commas rest
