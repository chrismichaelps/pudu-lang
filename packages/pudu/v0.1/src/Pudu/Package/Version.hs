{-| @Package.Version — release versions and the requirements that select them

    A release is named by a semantic version, and a dependency names the
    releases it accepts with a requirement. Both are read from text people write
    in a manifest, so each parser answers why a text is not one rather than
    failing quietly, and each value renders back to the spelling it came from. -}
module Pudu.Package.Version
  ( Version (..)
  , Requirement
  , parseVersion
  , renderVersion
  , parseRequirement
  , renderRequirement
  , satisfies
  , caretOf
  , exactly
  , newestSatisfying
  , isPrerelease
  ) where

import Data.Char (isDigit)
import Data.List (sortBy)
import Data.Ord (Down (..), comparing)
import Data.Text (Text)
import qualified Data.Text as Text

{-| A release version: three numbers and an optional pre-release label.

    Build metadata is refused rather than ignored: a registry that kept two
    releases differing only in metadata would have two archives for one
    version. -}
data Version = Version
  { versionMajor :: !Integer
  , versionMinor :: !Integer
  , versionPatch :: !Integer
  , versionPre :: ![Text]
  }
  deriving stock (Eq, Show)

{-| Precedence as the versioning rules define it: a pre-release sorts before
    its release, and pre-release fields compare numerically when both are
    numbers and by text otherwise, a number before a word. -}
instance Ord Version where
  compare left right =
    compare (triple left) (triple right) <> comparePre (versionPre left) (versionPre right)
   where
    triple v = (versionMajor v, versionMinor v, versionPatch v)

comparePre :: [Text] -> [Text] -> Ordering
comparePre [] [] = EQ
comparePre [] _ = GT
comparePre _ [] = LT
comparePre left right = go left right
 where
  go [] [] = EQ
  go [] _ = LT
  go _ [] = GT
  go (a : as) (b : bs) = field a b <> go as bs
  field a b = case (number a, number b) of
    (Just x, Just y) -> compare x y
    (Just _, Nothing) -> LT
    (Nothing, Just _) -> GT
    (Nothing, Nothing) -> compare a b
  number t = if not (Text.null t) && Text.all isDigit t then Just (read (Text.unpack t) :: Integer) else Nothing

isPrerelease :: Version -> Bool
isPrerelease = not . null . versionPre

parseVersion :: Text -> Either Text Version
parseVersion raw = do
  let text = Text.strip raw
  if Text.any (== '+') text
    then Left ("version " <> quoted text <> " carries build metadata, which a release version may not")
    else Right ()
  let (core, pre) = Text.breakOn "-" text
  case Text.splitOn "." core of
    [a, b, c] -> do
      major <- numeral a
      minor <- numeral b
      patch <- numeral c
      labels <- prerelease (Text.drop 1 pre)
      Right (Version major minor patch labels)
    _ -> Left (quoted text <> " is not a version: write MAJOR.MINOR.PATCH, such as 1.4.2")
 where
  numeral part
    | Text.null part || not (Text.all isDigit part) =
        Left (quoted raw <> " is not a version: each of its three parts is a whole number")
    | Text.length part > 1 && Text.head part == '0' =
        Left (quoted raw <> " is not a version: a part may not start with 0")
    | otherwise = Right (read (Text.unpack part))
  prerelease labels
    | Text.null labels = Right []
    | otherwise =
        let fields = Text.splitOn "." labels
         in if any Text.null fields || any (not . Text.all labelCharacter) fields
              then Left (quoted raw <> " has a pre-release label with an empty or invalid part")
              else Right fields
  labelCharacter c = isDigit c || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '-'

renderVersion :: Version -> Text
renderVersion (Version major minor patch pre) =
  Text.intercalate "." (map (Text.pack . show) [major, minor, patch])
    <> if null pre then "" else "-" <> Text.intercalate "." pre

{-| The releases a dependency accepts, as the bounds they reduce to, kept with
    the text that was written so the manifest reads back as it was. -}
data Requirement = Requirement
  { requirementText :: !Text
  , requirementBounds :: ![Bound]
  }
  deriving stock (Eq, Show)

data Bound
  = AtLeast !Version
  | Below !Version
  | Above !Version
  | AtMost !Version
  | Exactly !Version
  deriving stock (Eq, Show)

{-| Read a requirement: `1.4`, `^1.4.2`, `~1.4`, `=1.4.2`, `>=1.2, <1.8`, `*`.

    A bare version means the same as a caret, because what a person writing
    `1.4.2` means is "this or anything compatible with it". Missing parts count
    as zero, so `^1.4` accepts 1.4.0 and later. -}
parseRequirement :: Text -> Either Text Requirement
parseRequirement raw
  | Text.null text = Left "an empty requirement accepts nothing; write * to accept any release"
  | text == "*" = Right (Requirement text [])
  | otherwise = Requirement text . concat <$> traverse clause (map Text.strip (Text.splitOn "," text))
 where
  text = Text.strip raw
  clause part
    | Just rest <- Text.stripPrefix ">=" part = (\v -> [AtLeast v]) <$> partial rest
    | Just rest <- Text.stripPrefix "<=" part = (\v -> [AtMost v]) <$> partial rest
    | Just rest <- Text.stripPrefix ">" part = (\v -> [Above v]) <$> partial rest
    | Just rest <- Text.stripPrefix "<" part = (\v -> [Below v]) <$> partial rest
    | Just rest <- Text.stripPrefix "=" part = (\v -> [Exactly v]) <$> partial rest
    | Just rest <- Text.stripPrefix "~" part = tilde <$> partialCounted rest
    | Just rest <- Text.stripPrefix "^" part = caret . fst <$> partialCounted rest
    | otherwise = caret . fst <$> partialCounted part
  partial p = fst <$> partialCounted p
  partialCounted p =
    let stripped = Text.strip p
        (core, pre) = Text.breakOn "-" stripped
        parts = Text.splitOn "." core
     in if null parts || length parts > 3 || any Text.null parts
          then Left (quoted raw <> " is not a requirement: write a version such as ^1.4 or >=1.2, <2.0")
          else do
            let padded = parts <> replicate (3 - length parts) "0"
            version <- parseVersion (Text.intercalate "." padded <> pre)
            Right (version, length parts)
  caret v
    | versionMajor v > 0 = [AtLeast v, Below (Version (versionMajor v + 1) 0 0 [])]
    | versionMinor v > 0 = [AtLeast v, Below (Version 0 (versionMinor v + 1) 0 [])]
    | otherwise = [AtLeast v, Below (Version 0 0 (versionPatch v + 1) [])]
  tilde (v, written)
    | written == 1 = [AtLeast v, Below (Version (versionMajor v + 1) 0 0 [])]
    | otherwise = [AtLeast v, Below (Version (versionMajor v) (versionMinor v + 1) 0 [])]

renderRequirement :: Requirement -> Text
renderRequirement = requirementText

{-| Whether a release is one a requirement accepts.

    A pre-release is accepted only when the requirement names a pre-release of
    the same three numbers: asking for `^1.4` is not asking to be given
    `2.0.0-beta.1`, or even `1.5.0-beta.1`. -}
satisfies :: Requirement -> Version -> Bool
satisfies (Requirement _ bounds) version =
  all holds bounds && (not (isPrerelease version) || any namesThisPrerelease bounds)
 where
  holds bound = case bound of
    AtLeast v -> version >= v
    Below v -> version < v
    Above v -> version > v
    AtMost v -> version <= v
    Exactly v -> version == v
  namesThisPrerelease bound = case bound of
    AtLeast v -> isPrerelease v && sameCore v version
    Exactly v -> isPrerelease v && sameCore v version
    AtMost v -> isPrerelease v && sameCore v version
    Above v -> isPrerelease v && sameCore v version
    Below _ -> False
  sameCore a b =
    versionMajor a == versionMajor b && versionMinor a == versionMinor b && versionPatch a == versionPatch b

{-| The requirement a newly added dependency is written with: compatible with
    the release chosen. -}
caretOf :: Version -> Requirement
caretOf v = case parseRequirement ("^" <> renderVersion v) of
  Right requirement -> requirement
  Left _ -> Requirement (renderVersion v) [Exactly v]

exactly :: Version -> Requirement
exactly v = Requirement ("=" <> renderVersion v) [Exactly v]

{-| The newest of the given versions a requirement accepts. -}
newestSatisfying :: Requirement -> [Version] -> Maybe Version
newestSatisfying requirement versions =
  case sortBy (comparing Down) (filter (satisfies requirement) versions) of
    newest : _ -> Just newest
    [] -> Nothing

quoted :: Text -> Text
quoted t = "\"" <> t <> "\""
