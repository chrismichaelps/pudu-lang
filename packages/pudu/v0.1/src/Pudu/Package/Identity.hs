{-| @Package.Identity — what a package is called, and what a person may type

    A published package is `@handle/name`; a package that exists only on this
    machine, a path or a checkout, is known by the name its dependent gives it.
    Both become a directory under `deps/` and own one module root, so the rules
    for all three — names, roots, directories — live together here. -}
module Pudu.Package.Identity
  ( PackageId (..)
  , parsePackageId
  , renderPackageId
  , isRegistered
  , validSegment
  , defaultRoot
  , validRoot
  , reservedRoots
  , installDirectory
  , InstallSpec (..)
  , parseInstallSpec
  ) where

import Data.Char (isAsciiLower, isAsciiUpper, isDigit, toUpper)
import Data.Text (Text)
import qualified Data.Text as Text
import System.FilePath ((</>))

data PackageId
  = Registered !Text !Text
  | LocalName !Text
  deriving stock (Eq, Ord, Show)

isRegistered :: PackageId -> Bool
isRegistered (Registered _ _) = True
isRegistered _ = False

renderPackageId :: PackageId -> Text
renderPackageId (Registered handle name) = "@" <> handle <> "/" <> name
renderPackageId (LocalName name) = name

{-| Read `@handle/name` or a bare local name. -}
parsePackageId :: Text -> Either Text PackageId
parsePackageId raw = case Text.stripPrefix "@" text of
  Just rest -> case Text.splitOn "/" rest of
    [handle, name] -> do
      checkSegment "handle" handle
      checkSegment "project name" name
      if handle `elem` reservedHandles
        then Left ("@" <> handle <> " is a reserved handle")
        else Right (Registered handle name)
    _ -> Left (quote text <> " is not a package: write @handle/name")
  Nothing -> LocalName text <$ checkSegment "dependency name" text
 where
  text = Text.strip raw
  checkSegment what segment
    | validSegment segment = Right ()
    | otherwise =
        Left
          ( quote segment <> " is not a valid " <> what
              <> ": use lowercase letters, digits, and single hyphens, up to 39 characters"
          )

reservedHandles :: [Text]
reservedHandles = ["std", "core", "pudu", "admin"]

{-| Lowercase ASCII letters and digits with single hyphens between them. -}
validSegment :: Text -> Bool
validSegment segment =
  not (Text.null segment)
    && Text.length segment <= 39
    && Text.all (\c -> isAsciiLower c || isDigit c || c == '-') segment
    && Text.head segment /= '-'
    && Text.last segment /= '-'
    && not ("--" `Text.isInfixOf` segment)

{-| The module root a package owns when its manifest names none: the PascalCase
    of its name, `json-schema` → `JsonSchema`. -}
defaultRoot :: PackageId -> Text
defaultRoot package = Text.concat (map capitalise (Text.splitOn "-" (nameOf package)))
 where
  nameOf (Registered _ name) = name
  nameOf (LocalName name) = name
  capitalise part = case Text.uncons part of
    Just (c, rest) -> Text.cons (toUpper c) rest
    Nothing -> part

reservedRoots :: [Text]
reservedRoots = ["Std", "Core"]

{-| A module root is one module segment: a capital letter, then letters and
    digits. -}
validRoot :: Text -> Either Text Text
validRoot root
  | root `elem` reservedRoots = Left (root <> " belongs to the compiler; a package may not own it")
  | Just (first, rest) <- Text.uncons root
  , isAsciiUpper first
  , Text.all (\c -> isAsciiLower c || isAsciiUpper c || isDigit c) rest =
      Right root
  | otherwise = Left (quote root <> " is not a module root: start with a capital letter, then letters and digits")

{-| Where an installed package lives, under the project's `deps/`. -}
installDirectory :: FilePath -> PackageId -> FilePath
installDirectory root (Registered handle name) = root </> "deps" </> ("@" <> Text.unpack handle) </> Text.unpack name
installDirectory root (LocalName name) = root </> "deps" </> Text.unpack name

{-| What `pudu install` is asked to add. -}
data InstallSpec
  = SpecRegistry !PackageId !(Maybe Text)
  | SpecPath !FilePath
  | SpecGit !Text !(Maybe Text)
  deriving stock (Eq, Show)

{-| Read one argument to `pudu install`.

    `@h/n` and `@h/n@1.2` name registry releases; anything that starts like a
    path is a path; a URL ending in `.git`, or starting `git+`, `git@`, or with
    a `#rev`, is a repository. -}
parseInstallSpec :: Text -> Either Text InstallSpec
parseInstallSpec raw
  | Just rest <- Text.stripPrefix "@" text =
      let (identity, version) = Text.breakOn "@" rest
       in do
            package <- parsePackageId ("@" <> identity)
            let wanted = Text.drop 1 version
            if not (Text.null version) && Text.null wanted
              then Left (quote text <> " ends with @ but names no version")
              else Right (SpecRegistry package (if Text.null wanted then Nothing else Just wanted))
  | isPath = Right (SpecPath (Text.unpack text))
  | isGit =
      let unprefixed = maybe text id (Text.stripPrefix "git+" text)
          (url, rev) = Text.breakOn "#" unprefixed
       in Right (SpecGit url (if Text.null rev then Nothing else Just (Text.drop 1 rev)))
  | otherwise =
      Left
        ( quote text
            <> " is not something to install: write @handle/name, @handle/name@1.2.3, a path such as ./lib, or a git URL"
        )
 where
  text = Text.strip raw
  isPath = any (`Text.isPrefixOf` text) ["./", "../", "/", "~/"] || text == "." || text == ".."
  isGit =
    any (`Text.isPrefixOf` text) ["git+", "git@", "https://", "http://", "ssh://", "file://"]
      && (".git" `Text.isInfixOf` text || "#" `Text.isInfixOf` text || "git+" `Text.isPrefixOf` text || "git@" `Text.isPrefixOf` text)

quote :: Text -> Text
quote t = "\"" <> t <> "\""
