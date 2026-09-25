{-| @Package.Solve — one version of each package, chosen for the whole program

    A dependency graph names each package by what it accepts: a requirement on
    registry releases, a repository at a revision, or a directory. The solver
    picks one release per package that every requirement on it accepts,
    preferring what the lock already chose and otherwise the newest, and tries
    older candidates when a newer one's own requirements cannot be met. A
    yanked release is chosen only when the lock already holds it; a recent
    release only when the lock holds it or a requirement names it exactly.

    What a registry holds is asked through `Registry`, so the solver neither
    knows nor cares whether the answer came over the network or from the
    cache. -}
module Pudu.Package.Solve
  ( Registry (..)
  , ReleaseInfo (..)
  , noRegistry
  , Want (..)
  , Node (..)
  , NodeSource (..)
  , Preference (..)
  , solve
  ) where

import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.List (sortBy)
import qualified Data.Map.Strict as Map
import Data.Ord (Down (..), comparing)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Package.Identity (PackageId, parsePackageId, renderPackageId)
import Pudu.Package.Version
  ( Bound (..)
  , Requirement (..)
  , Version
  , parseRequirement
  , parseVersion
  , renderRequirement
  , renderVersion
  , satisfies
  )

{-| One published release, as a registry describes it. -}
data ReleaseInfo = ReleaseInfo
  { releaseVersion :: !Version
  , releaseChecksum :: !Text
  , releaseDependencies :: ![(Text, Text)]
  , releaseRoot :: !Text
  , releaseYanked :: !Bool
  , releaseRecent :: !Bool
  -- ^ Published more recently than the minimum release age.
  }
  deriving stock (Eq, Show)

{-| What the installer asks of a registry: the releases of a package, and a
    release's files, unpacked in the cache after its archive's digest was
    checked against the one given. -}
data Registry = Registry
  { registryUrl :: !Text
  , registryReleases :: PackageId -> IO (Either Text [ReleaseInfo])
  , registryFetch :: PackageId -> Text -> Text -> IO (Either Text FilePath)
  }

noRegistry :: Registry
noRegistry =
  Registry
    { registryUrl = ""
    , registryReleases = \package -> pure (Left (unconfigured package))
    , registryFetch = \package _ _ -> pure (Left (unconfigured package))
    }
 where
  unconfigured package = renderPackageId package <> " is a registry package, and no registry is configured"

{-| What one requester asks for. -}
data Want
  = WantRelease !Text
  | WantFixed !NodeSource !Text !Text ![(Text, Want)]
  deriving stock (Eq, Show)

{-| Where a chosen package's content comes from. -}
data NodeSource
  = FromRegistry !Text !Text
  | FromGit !Text !Text !FilePath
  | FromPath !FilePath
  deriving stock (Eq, Show)

{-| A chosen package. -}
data Node = Node
  { nodeId :: !PackageId
  , nodeVersion :: !Text
  , nodeSource :: !NodeSource
  , nodeRoot :: !Text
  , nodeDependencies :: ![PackageId]
  }
  deriving stock (Eq, Show)

{-| What the lock chose before, and which packages to choose afresh. -}
data Preference = Preference
  { preferredVersions :: !(Map.Map PackageId Text)
  , refreshed :: !(PackageId -> Bool)
  }

{-| The chosen packages, or the requirements that cannot all be met.

    A fixed want — a repository or a directory — arrives as one package with its
    own dependencies already read, because fetching one does not depend on
    what else is chosen. -}
solve :: Registry -> Preference -> [(Text, PackageId, Want)] -> IO (Either Text [Node])
solve registry preference roots = do
  known <- newIORef Map.empty
  let releasesOf package = do
        cached <- Map.lookup package <$> readIORef known
        case cached of
          Just answer -> pure answer
          Nothing -> do
            answer <- registryReleases registry package
            modifyIORef' known (Map.insert package answer)
            pure answer
      go chosen asked [] = pure (Right (chosen, asked))
      go chosen asked ((who, package, want) : rest) = case want of
        WantFixed source version root dependencies -> case Map.lookup package chosen of
          Just node
            | nodeSource node == source -> go chosen asked rest
            | otherwise ->
                pure
                  ( Left
                      ( renderPackageId package <> " is asked for from two places: " <> describe (nodeSource node)
                          <> " and " <> describe source <> " (by " <> who <> ")"
                      )
                  )
          Nothing -> do
            let node = Node package version source root [dependency | (_, dependency, _) <- childWants]
                childWants = [(renderPackageId package, dependency, w) | (name, w) <- dependencies, Right dependency <- [parseId name]]
            go (Map.insert package node chosen) asked (rest <> childWants)
        WantRelease text -> case parseRequirement text of
          Left problem -> pure (Left (who <> " asks for " <> renderPackageId package <> " " <> text <> ": " <> problem))
          Right requirement -> do
            let asked' = Map.insertWith (<>) package [(who, requirement)] asked
                everyone = Map.findWithDefault [] package asked'
            case Map.lookup package chosen of
              Just node -> case parseVersion (nodeVersion node) of
                Right v | satisfies requirement v -> go chosen asked' rest
                _ -> pure (Left (conflict package everyone))
              Nothing -> do
                listed <- releasesOf package
                case listed of
                  Left problem -> pure (Left problem)
                  Right releases -> do
                    let locked = if refreshed preference package then Nothing else Map.lookup package (preferredVersions preference)
                        isLocked r = Just (renderVersion (releaseVersion r)) == locked
                        named r = any (\(_, req) -> Exactly (releaseVersion r) `elem` requirementBounds req) everyone
                        acceptable r =
                          all (\(_, req) -> satisfies req (releaseVersion r)) everyone
                            && (not (releaseYanked r) || isLocked r)
                            && (not (releaseRecent r) || isLocked r || named r)
                        ordered =
                          sortBy (comparing (\r -> (Just (renderVersion (releaseVersion r)) /= locked, Down (releaseVersion r))))
                            (filter acceptable releases)
                        held = [r | r <- releases, all (\(_, req) -> satisfies req (releaseVersion r)) everyone, not (releaseYanked r), releaseRecent r]
                    if null ordered
                      then pure (Left (conflict package everyone <> available releases <> tooRecent package held))
                      else attempt package ordered chosen asked' rest
      attempt _ [] _ _ _ = pure (Left "no release satisfies every requirement")
      attempt package (release : others) chosen asked rest = do
        let childWants =
              [ (renderPackageId package <> " " <> renderVersion (releaseVersion release), dependency, WantRelease req)
              | (name, req) <- releaseDependencies release
              , Right dependency <- [parseId name]
              ]
            node =
              Node package (renderVersion (releaseVersion release))
                (FromRegistry (registryUrl registry) (releaseChecksum release))
                (releaseRoot release)
                [dependency | (_, dependency, _) <- childWants]
        outcome <- go (Map.insert package node chosen) asked (rest <> childWants)
        case outcome of
          Right done -> pure (Right done)
          Left problem
            | null others -> pure (Left problem)
            | otherwise -> attempt package others chosen asked rest
  result <- go Map.empty Map.empty roots
  pure (fmap (Map.elems . fst) result)
 where
  parseId = parsePackageId
  describe source = case source of
    FromRegistry url _ -> "the registry at " <> url
    FromGit url commit _ -> url <> " at " <> Text.take 12 commit
    FromPath path -> Text.pack path
  conflict package everyone =
    "no release of " <> renderPackageId package <> " satisfies every requirement on it:\n"
      <> Text.unlines [ "  " <> renderRequirement req <> " asked by " <> who | (who, req) <- reverse everyone ]
  tooRecent package held = case held of
    [] -> ""
    _ ->
      "\n  " <> Text.intercalate ", " (map (renderVersion . releaseVersion) held)
        <> " was published within the minimum release age; install one by its exact version, such as "
        <> renderPackageId package <> "@" <> renderVersion (releaseVersion (last held))
        <> ", or lower min-release-age under [install] in pudu.toml"
  available releases =
    if null releases
      then "  it has no releases"
      else "  released: " <> Text.intercalate ", " (map (renderVersion . releaseVersion) (take 8 (sortBy (comparing (Down . releaseVersion)) releases)))
