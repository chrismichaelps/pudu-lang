{-| @Package.ManifestEdit — change one dependency line of a person's manifest

    `pudu.toml` is written by people, so `pudu install` and `pudu uninstall`
    change the one line they mean and leave every comment, blank line, and key
    order as it was. A dependency is found by its key, quoted or not. -}
module Pudu.Package.ManifestEdit
  ( setDependency
  , removeDependency
  , setPackageVersion
  , dependencyKey
  ) where

import Data.Text (Text)
import qualified Data.Text as Text

{-| How a key is written: a registry name has an `@` and a `/`, which a bare
    TOML key may not hold, so it is quoted. -}
dependencyKey :: Text -> Text
dependencyKey key
  | Text.all (\c -> c == '-' || c == '_' || c `elem` ['a' .. 'z'] || c `elem` ['A' .. 'Z'] || c `elem` ['0' .. '9']) key = key
  | otherwise = "\"" <> key <> "\""

{-| Set `key = value` under `[dependencies]`, replacing the line that names the
    key, or adding one at the end of the section, or adding the section. -}
setDependency :: Text -> Text -> Text -> Text
setDependency key value contents =
  let entry = dependencyKey key <> " = " <> value
      rows = Text.lines contents
   in case sectionBounds "dependencies" rows of
        Nothing ->
          Text.unlines (dropTrailingBlank rows <> ["", "[dependencies]", entry])
        Just (start, end) ->
          case [i | i <- [start + 1 .. end - 1], namesKey key (rows !! i)] of
            i : _ -> Text.unlines (take i rows <> [entry] <> drop (i + 1) rows)
            [] ->
              let lastEntry = lastContent rows start end
               in Text.unlines (take (lastEntry + 1) rows <> [entry] <> drop (lastEntry + 1) rows)

removeDependency :: Text -> Text -> Maybe Text
removeDependency key contents =
  let rows = Text.lines contents
   in case sectionBounds "dependencies" rows of
        Nothing -> Nothing
        Just (start, end) -> case [i | i <- [start + 1 .. end - 1], namesKey key (rows !! i)] of
          i : _ -> Just (Text.unlines (take i rows <> drop (i + 1) rows))
          [] -> Nothing

{-| Set `version` under `[package]`, for `pudu release`. -}
setPackageVersion :: Text -> Text -> Text
setPackageVersion version contents =
  let rows = Text.lines contents
      entry = "version = \"" <> version <> "\""
   in case sectionBounds "package" rows of
        Nothing -> contents
        Just (start, end) -> case [i | i <- [start + 1 .. end - 1], namesKey "version" (rows !! i)] of
          i : _ -> Text.unlines (take i rows <> [entry] <> drop (i + 1) rows)
          [] -> Text.unlines (take (start + 1) rows <> [entry] <> drop (start + 1) rows)

{-| The heading's line and the line after the section's last one. -}
sectionBounds :: Text -> [Text] -> Maybe (Int, Int)
sectionBounds name rows = case [i | (i, row) <- zip [0 ..] rows, heading row == Just name] of
  start : _ ->
    let after = [i | (i, row) <- zip [0 ..] rows, i > start, heading row /= Nothing]
     in Just (start, case after of end : _ -> end; [] -> length rows)
  [] -> Nothing
 where
  heading row = Text.strip <$> (Text.stripPrefix "[" (Text.strip row) >>= Text.stripSuffix "]")

lastContent :: [Text] -> Int -> Int -> Int
lastContent rows start end =
  case reverse [i | i <- [start + 1 .. end - 1], not (Text.null (Text.strip (rows !! i)))] of
    i : _ -> i
    [] -> start

namesKey :: Text -> Text -> Bool
namesKey key row =
  let (left, rest) = Text.breakOn "=" (Text.strip row)
      written = Text.strip left
   in not (Text.null rest) && not ("#" `Text.isPrefixOf` Text.strip row)
        && (written == key || written == "\"" <> key <> "\"" || written == "'" <> key <> "'")

dropTrailingBlank :: [Text] -> [Text]
dropTrailingBlank = reverse . dropWhile (Text.null . Text.strip) . reverse
