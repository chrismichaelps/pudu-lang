{-| @Eval.Confinement — a run that may not reach beyond its own output.

    `pudu run --confined` evaluates a program that someone other than the
    person running it wrote: the playground runs what a reader typed. Such a
    program may print, read the clock, draw random numbers, and use threads,
    but it may not read or write files, start programs, open connections, or
    call foreign code, whatever it imports.

    The switch is set once for the whole process, before the program starts,
    and nothing sets it back, so no code the program runs can lift it. The
    effects a confined run keeps are listed by name; one added to the runtime
    later is refused here until it is listed. -}
module Pudu.Eval.Confinement
  ( confine
  , guardConfined
  , keptWhenConfined
  ) where

import Control.Monad (when)
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Text (Text)
import Pudu.Eval.Env (Eval (..), Evaluator (..), abortAt)
import Pudu.Eval.Value (Builtin (..))
import Pudu.Source (Span)
import System.IO.Unsafe (unsafePerformIO)

confinement :: IORef Bool
confinement = unsafePerformIO (newIORef False)
{-# NOINLINE confinement #-}

{-| Confine every evaluation this process performs from now on. -}
confine :: IO ()
confine = writeIORef confinement True

{-| Whether a confined run may still perform an effect: writing its own two
    streams, reading a line it was given, the clock and time zones, randomness,
    compression, its own threads and their channels, locks, and cells, and
    stopping. -}
keptWhenConfined :: Builtin -> Bool
keptWhenConfined builtin = case builtin of
  PrintBuiltin -> True
  PrintErrorBuiltin -> True
  PrintPartBuiltin -> True
  PrintErrorPartBuiltin -> True
  ReadLineBuiltin -> True
  ArgumentsBuiltin -> True
  ExitBuiltin -> True
  ClockBuiltin -> True
  NowBuiltin -> True
  FormatTimeBuiltin -> True
  ParseTimeBuiltin -> True
  ZoneOffsetBuiltin -> True
  PathSeparatorsBuiltin -> True
  SearchSeparatorBuiltin -> True
  DeflateBuiltin -> True
  InflateBuiltin -> True
  GzipCompressBuiltin -> True
  GzipDecompressBuiltin -> True
  SecureBytesBuiltin -> True
  SignalWatchStopBuiltin -> True
  SignalStopRequestedBuiltin -> True
  SpawnThreadBuiltin -> True
  JoinThreadBuiltin -> True
  SleepBuiltin -> True
  ChannelOpenBuiltin -> True
  ChannelPushBuiltin -> True
  ChannelPullBuiltin -> True
  ChannelWaitingBuiltin -> True
  ChannelFinishBuiltin -> True
  MutexOpenBuiltin -> True
  MutexAcquireBuiltin -> True
  MutexReleaseBuiltin -> True
  CellOpenBuiltin -> True
  CellGetBuiltin -> True
  CellSwapBuiltin -> True
  _ -> False

{-| Stop the program at `spanValue` when this process is confined and the
    operation is not one a confined run keeps. -}
guardConfined :: Span -> Text -> Bool -> Evaluator ()
guardConfined spanValue operation kept = do
  confined <- Evaluator $ \env -> (`Done` env) <$> readIORef confinement
  when (confined && not kept) $
    abortAt (Just spanValue) "E7027" (operation <> " is not available here")
      ( Just
          ( "this program runs confined, as the playground runs every program: it may print, "
              <> "read the clock, and use threads, but not use files, start programs, reach the "
              <> "network, or call foreign code. Install Pudu to run it on your own machine"
          )
      )
