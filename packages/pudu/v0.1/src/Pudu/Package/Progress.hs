{-| @Package.Progress — events emitted while dependencies are installed

    `Progress` receives each `Event` as the installer starts or finishes a
    step. It may be called from several threads at once. `silentProgress`
    discards every event. -}
module Pudu.Package.Progress
  ( Progress (..)
  , Event (..)
  , silentProgress
  , emit
  ) where

import Data.Text (Text)
import Pudu.Package.Identity (PackageId)

data Event
  = -- | A repository is being fetched over the network.
    FetchStarted !Text
  | -- | The fetch of a repository finished.
    FetchFinished !Text
  | -- | A repository was answered from the cache without a fetch.
    CacheHit !Text
  | -- | A commit is being written out of a repository into the cache.
    CheckoutStarted !Text !Text
  | -- | Resolution finished; the count includes path dependencies.
    Resolved !Int
  | -- | A package's files are being copied into `deps/`.
    CopyStarted !PackageId !Text
  | -- | A package's files are in `deps/`.
    CopyFinished !PackageId
  | -- | An installed package already matched the lock.
    UpToDate !PackageId
  deriving stock (Eq, Show)

newtype Progress = Progress {progressEmit :: Event -> IO ()}

silentProgress :: Progress
silentProgress = Progress (const (pure ()))

emit :: Progress -> Event -> IO ()
emit = progressEmit
