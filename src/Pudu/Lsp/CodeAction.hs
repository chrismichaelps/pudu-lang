{-| @Program.Lsp.CodeAction — context-sensitive code actions and fixes -}
module Pudu.Lsp.CodeAction (codeActionsAt) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Format (FormatResult (..), formatSource)
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Feature (rangeOfOffsets)
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.Protocol (Range, rangeJson)

codeActionsAt :: Text -> Analysis -> Range -> Json -> Json
codeActionsAt uri value _ _ =
  let content = analysisText value
      result = formatText' (formatSource (analysisSource value))
      actions =
        [ JsonObject
            [ ("title", JsonText "Format document with pudu fmt")
            , ("kind", JsonText "source.fixAll")
            , ( "edit"
              , JsonObject
                  [ ( "changes"
                    , JsonObject
                        [ ( uri
                          , JsonArray
                              [ JsonObject
                                  [ ( "range"
                                    , rangeJson (rangeOfOffsets content 0 (Text.length content))
                                    )
                                  , ("newText", JsonText result)
                                  ]
                              ]
                          )
                        ]
                    )
                  ]
              )
            ]
        | result /= content
        ]
   in JsonArray actions
