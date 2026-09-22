{-| @Package.Progress — what installing is doing, as events a front end can show

    The installer says what it starts and finishes and never decides how that
    looks: a terminal shows a live line, a log shows one line per event, a test
    shows nothing. Events may arrive from several threads at once, so a
    `Progress` must accept them concurrently. -}
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
  | -- | A locked commit was already in the cache; nothing was run.
    CacheHit !Text
  | -- | A commit is being written out of a repository into the cache.
    CheckoutStarted !Text !Text
  | -- | Every package has been chosen; the count includes directories used in place.
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
