{-| @Program.Lsp.Completion — member and identifier completions -}
module Pudu.Lsp.Completion (completionAt) where

import Data.Char (isAlphaNum)
import Data.List (nub, sort)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Doc (DocEntry (..), DocIndex (..), DocKind (..))
import Pudu.Eval.Operator (builtinMethodNamesFor)
import Pudu.Lsp.Documents (Analysis (..), Documents, documentOf)
import Pudu.Lsp.Feature (completionItems, offsetAt)
import Pudu.Lsp.Json (Json (..), lookupField)
import Pudu.Lsp.Protocol (positionOf)
import Pudu.Type (Type (..), narrowestAt)
import Pudu.Type.Value (nominalName)

completionAt :: Documents -> Json -> Json
completionAt documents parameters = case documentOf documents parameters of
  Nothing -> JsonArray []
  Just value -> case located documents parameters of
    Just (_, offset) -> case memberMethods value offset of
      names@(_ : _) -> JsonArray (map methodItem names)
      [] -> JsonArray (generalCompletions (analysisProgramIndex value))
    Nothing -> completionItems (analysisProgramIndex value)

generalCompletions :: DocIndex -> [Json]
generalCompletions index =
  case completionItems index of
    JsonArray items -> items <> keywordCompletions <> primitiveCompletions
    _ -> keywordCompletions <> primitiveCompletions

keywordCompletions :: [Json]
keywordCompletions =
  [ JsonObject [("label", JsonText kw), ("kind", JsonNumber 14), ("detail", JsonText "keyword")]
  | kw <-
      [ "fn", "let", "var", "const", "mut", "if", "else", "match", "case", "for"
      , "in", "while", "loop", "break", "continue", "return", "type", "enum"
      , "struct", "trait", "impl", "where", "export", "import", "unsafe", "foreign", "dynamic"
      ]
  ]

primitiveCompletions :: [Json]
primitiveCompletions =
  [ JsonObject [("label", JsonText ty), ("kind", JsonNumber 25), ("detail", JsonText "type")]
  | ty <-
      [ "Int", "Int8", "Int16", "Int32", "Int64", "Int128", "UInt", "UInt8", "UInt16"
      , "UInt32", "UInt64", "UInt128", "Float32", "Float64", "Decimal", "BigInt"
      , "Str", "Char", "Bool", "Bytes", "Array", "Map", "Option", "Result"
      ]
  ]

memberMethods :: Analysis -> Int -> [Text]
memberMethods value offset = case receiverEnd (analysisText value) offset of
  Nothing -> []
  Just dotOffset -> case analysisTypes value >>= narrowestAt (dotOffset - 1) of
    Nothing -> []
    Just typeValue ->
      let owner = ownerNameOf typeValue
       in sort (nub (methodsOfType typeValue <> implMethodsFor (analysisProgramIndex value) owner))

implMethodsFor :: DocIndex -> Text -> [Text]
implMethodsFor index owner
  | Text.null owner = []
  | otherwise =
      [ docName entry
      | entry <- indexEntries index
      , DocMethod target <- [docKind entry]
      , target == owner
      ]

ownerNameOf :: Type -> Text
ownerNameOf typeValue = case throughReferenceType typeValue of
  NominalType identity _ -> nominalName identity
  _ -> ""

receiverEnd :: Text -> Int -> Maybe Int
receiverEnd content offset =
  let before = Text.take offset content
      typed = Text.takeWhileEnd nameScalar before
      atDot = Text.dropEnd (Text.length typed) before
   in if Text.isSuffixOf "." atDot then Just (Text.length atDot - 1) else Nothing
 where
  nameScalar scalar = isAlphaNum scalar || scalar == '_'

methodsOfType :: Type -> [Text]
methodsOfType typeValue = case throughReferenceType typeValue of
  NominalType identity _ -> builtinMethodNamesFor (nominalName identity)
  _ -> []

throughReferenceType :: Type -> Type
throughReferenceType typeValue = case typeValue of
  ReferenceTypeValue _ target -> throughReferenceType target
  other -> other

methodItem :: Text -> Json
methodItem name =
  JsonObject [("label", JsonText name), ("kind", JsonNumber 2), ("detail", JsonText "method")]

located :: Documents -> Json -> Maybe (Analysis, Int)
located documents parameters = do
  value <- documentOf documents parameters
  position <- lookupField "position" parameters >>= positionOf
  pure (value, offsetAt (analysisText value) position)
