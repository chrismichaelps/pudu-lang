{-| @Doc.Json.Module — emits the index in the shape a tool consumes -}
module Pudu.Doc.Json
  ( encodeEntry
  , encodeIndex
  , escapeJson
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Doc (DocEntry (..), DocIndex (..), kindLabel)
import Pudu.Type.Value (capabilityName)
import Pudu.Doc.Signature
  ( SigType (..)
  , Signature (..)
  , renderSigType
  , renderSignature
  )

{-| Encode the whole index.

    The encoding is written by hand rather than pulled from a library because
    the shape is small, fixed, and part of this project's public contract with
    editors: a dependency would put that contract in someone else's release
    schedule for no expressive gain.

    The output carries both the rendered signature and its structure. An editor
    showing a hover wants the rendering; a search server indexing many modules
    wants the structure, and asking it to re-parse the rendering would make the
    renderer part of the protocol. -}
encodeIndex :: DocIndex -> Text
encodeIndex index =
  "{\"entries\":[" <> Text.intercalate "," (map encodeEntry (indexEntries index)) <> "]}"

encodeEntry :: DocEntry -> Text
encodeEntry value =
  object
    [ ("name", string (docName value))
    , ("kind", string (kindLabel (docKind value)))
    , ("module", string (docModule value))
    , ("signature", maybe "null" (string . renderSignature) (docSignature value))
    , ("shape", maybe "null" encodeSignature (docSignature value))
    , ("doc", array (map string (docComment value)))
    , ("span", array [number (fst (docSpan value)), number (snd (docSpan value))])
    ]

encodeSignature :: Signature -> Text
encodeSignature signature =
  object
    [ ("arguments", array (map encodeSigType (signatureArguments signature)))
    , ("result", encodeSigType (signatureResult signature))
    ,
      ( "constraints"
      , array
          [ object [("variable", string name), ("bounds", array (map string bounds))]
          | (name, bounds) <- signatureConstraints signature
          ]
      )
    ]

{-| One type, encoded so a consumer can match on it without parsing text.

    Every node carries its rendered form beside its structure, so a consumer
    that only wants to display a fragment never has to reimplement rendering. -}
encodeSigType :: SigType -> Text
encodeSigType sigType =
  object (("rendered", string (renderSigType sigType)) : structure sigType)
 where
  structure value = case value of
    SigCon name arguments ->
      [("form", string "con"), ("name", string name), ("arguments", array (map encodeSigType arguments))]
    SigVar name -> [("form", string "var"), ("name", string name)]
    SigRef mutable target ->
      [("form", string "ref"), ("mutable", boolean mutable), ("target", encodeSigType target)]
    SigTuple members -> [("form", string "tuple"), ("members", array (map encodeSigType members))]
    SigFun inputs result ->
      [ ("form", string "fn")
      , ("inputs", array (map encodeSigType inputs))
      , ("result", encodeSigType result)
      ]
    SigRestricted capabilities inner ->
      [ ("form", string "restricted")
      , ("capabilities", array (map (string . capabilityName) capabilities))
      , ("target", encodeSigType inner)
      ]
    SigUnit -> [("form", string "unit")]
    SigNever -> [("form", string "never")]
    SigUnknown -> [("form", string "unknown")]

object :: [(Text, Text)] -> Text
object fields =
  "{" <> Text.intercalate "," [string key <> ":" <> value | (key, value) <- fields] <> "}"

array :: [Text] -> Text
array values = "[" <> Text.intercalate "," values <> "]"

string :: Text -> Text
string value = "\"" <> escapeJson value <> "\""

number :: Int -> Text
number = Text.pack . show

boolean :: Bool -> Text
boolean value = if value then "true" else "false"

{-| Escape what JSON requires and what a control scalar would otherwise break.

    Scalars below U+0020 are escaped numerically rather than dropped: an index
    is generated from source a reader wrote, and silently losing a scalar would
    make the output disagree with the file it describes. -}
escapeJson :: Text -> Text
escapeJson = Text.concatMap escape
 where
  escape scalar = case scalar of
    '"' -> "\\\""
    '\\' -> "\\\\"
    '\n' -> "\\n"
    '\r' -> "\\r"
    '\t' -> "\\t"
    _
      | scalar < ' ' -> "\\u" <> Text.justifyRight 4 '0' (Text.pack (hex (fromEnum scalar)))
      | otherwise -> Text.singleton scalar

  hex value
    | value == 0 = "0"
    | otherwise = go value ""
   where
    go remaining accumulated
      | remaining == 0 = accumulated
      | otherwise =
          go (remaining `div` 16) (digits !! (remaining `mod` 16) : accumulated)
    digits = "0123456789abcdef"
