{-| @Eval.Foreign.Resource — settles native release obligations and records cleanup failures -}
module Pudu.Eval.Foreign.Resource
  ( prepareReleases
  , releaseHandle
  , cleanupFailedOutputs
  , cleanupUnclaimed
  ) where

import Control.Exception (IOException, displayException, try)
import Data.Int (Int64)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Severity (Warning), diagnostic, mkDiagnosticCode)
import Pudu.Eval.Value (ForeignBinding (..), ForeignRelease (..), ForeignSlot (..))
import Pudu.Foreign.Call (CrossedValue (..), callSymbol, resolveSymbol)
import Pudu.Foreign.Crossing (Crossing (..))
import Pudu.Foreign.Ownership
  ( ForeignStore, claimAllOwned, takeOwned, recordForeignDiagnostic )
import Pudu.Source (Span)

{-| Resolve every destructor before entering a resource-producing symbol. -}
prepareReleases :: ForeignBinding -> IO (Either Text ())
prepareReleases binding = resolveAll (Set.toList (Set.fromList declarations))
 where
  declarations =
    [(foreignReleaseLibrary release, foreignReleaseVersion release, foreignReleaseSymbol release)
    | release <- maybe [] pure (foreignBindingReleasedBy binding)
      <> [release | Just slot <- foreignBindingSlots binding
                  , Just release <- [foreignSlotReleasedBy slot]]]
  resolveAll [] = pure (Right ())
  resolveAll ((library, version, symbol) : rest) = do
    found <- resolveSymbol library version symbol
    case found of
      Left problem -> pure (Left ("release " <> symbol <> ": " <> problem))
      Right _ -> resolveAll rest

{-| Cleanup failures are warnings; a failed destructor is never retried. -}
releaseHandle :: ForeignStore -> Span -> ForeignRelease -> Text -> Int64 -> IO ()
releaseHandle store spanValue release name address = do
  attempted <- try releaseOnce :: IO (Either IOException (Either Text ()))
  case attempted of
    Left problem -> reportCleanup store spanValue (Text.pack (displayException problem))
    Right (Left problem) -> reportCleanup store spanValue problem
    Right (Right ()) -> pure ()
 where
  releaseOnce = do
    found <- resolveSymbol (foreignReleaseLibrary release) (foreignReleaseVersion release)
      (foreignReleaseSymbol release)
    case found of
      Left problem -> pure (Left (foreignReleaseSymbol release <> ": " <> problem))
      Right symbol -> do
        result <- callSymbol symbol [(HandleCrossing name, False, CrossedHandle name address)] NothingCrossing
        pure $ case result of
          Left problem -> Left (foreignReleaseSymbol release <> ": " <> Text.pack (show problem))
          Right _ -> Right ()

reportCleanup :: ForeignStore -> Span -> Text -> IO ()
reportCleanup store spanValue message =
  mapM_ (recordForeignDiagnostic store) $ do
    code <- mkDiagnosticCode "W7027"
    diagnostic code Warning spanValue ("foreign cleanup failed: " <> message)

{-| Retain ownership obligations even when native text conversion failed. -}
cleanupFailedOutputs :: Span -> ForeignBinding -> ForeignStore -> [(Maybe Int, Text, Int64)] -> IO ()
cleanupFailedOutputs spanValue binding store handles =
  do
    let declarations = Map.fromList
          ((Nothing, (foreignBindingResult binding, foreignBindingReleasedBy binding))
            : [(Just index, (foreignSlotCrossing slot, foreignSlotReleasedBy slot))
              | (index, Just slot) <- zip [0 ..] (foreignBindingSlots binding)])
        resources = [(address, name, release)
                    | (position, name, address) <- handles
                    , Just (HandleCrossing expected, Just release) <- [Map.lookup position declarations]
                    , expected == name]
    if length resources /= length handles
      then reportCleanup store spanValue "a native output has no matching declared release"
      else pure ()
    claimed <- claimAllOwned store
      [(address, releaseHandle store spanValue release name address) | (address, name, release) <- resources]
    case claimed of
      Left protected -> cleanupUnclaimed store spanValue protected resources
      Right () -> mapM_ (\(address, name, release) -> do
        taken <- takeOwned store address
        case taken of
          Nothing -> pure ()
          Just _ -> releaseHandle store spanValue release name address) resources

{-| Protected addresses and conflicting destructors never enter cleanup. -}
cleanupUnclaimed :: ForeignStore -> Span -> [Int64] -> [(Int64, Text, ForeignRelease)] -> IO ()
cleanupUnclaimed store spanValue protected resources = mapM_ cleanup (Map.toList grouped)
 where
  held = Set.fromList protected
  grouped = Map.fromListWith (<>)
    [(address, [(name, release)]) | (address, name, release) <- resources]
  cleanup (address, obligations)
    | Set.member address held = pure ()
    | otherwise = case obligations of
        first@(name, release) : rest
          | all (== first) rest -> releaseHandle store spanValue release name address
        _ -> reportCleanup store spanValue "one native address has conflicting release obligations"

