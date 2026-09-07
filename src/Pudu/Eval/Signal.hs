{-# LANGUAGE CPP #-}

{-| @Eval.Signal — the request to stop that arrives from outside the program

    A supervisor stops a service by sending it a signal and then waiting a
    little before killing it. A program that cannot observe the signal spends
    that grace period unaware and is killed mid-request, so every deploy drops
    whatever was in flight. Observing it is what turns that into a drain.

    The signal is recorded rather than acted on. A handler runs between two
    instructions of the evaluator, where almost nothing is safe to do and
    nothing knows what the program was in the middle of; setting one flag is
    safe there, and the program reads the flag where it is ready to stop. -}
module Pudu.Eval.Signal
  ( stopRequested
  , watchForStop
  ) where

import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import System.IO.Unsafe (unsafePerformIO)

#if defined(PUDU_POSIX_SIGNALS)
import System.Posix.Signals
  ( Handler (Catch)
  , installHandler
  , sigINT
  , sigTERM
  )
#endif

{-| Whether a stop has been asked for.

    One flag for the whole process, because the signal is delivered to the
    process rather than to any part of it. -}
requested :: IORef Bool
requested = unsafePerformIO (newIORef False)
{-# NOINLINE requested #-}

{-| Whether handlers are already installed.

    Installing twice is harmless, but a program that watches inside a loop
    would then reinstall on every turn, and the second install is work that
    answers nothing. -}
watching :: IORef Bool
watching = unsafePerformIO (newIORef False)
{-# NOINLINE watching #-}

stopRequested :: IO Bool
stopRequested = readIORef requested

{-| Begin observing the two signals that mean "stop".

    `SIGTERM` is what a supervisor sends, and `SIGINT` is what a terminal sends
    on Ctrl-C. Both are requests rather than orders — `SIGKILL` is the order,
    and nothing can observe that — so both are recorded the same way.

    Answers whether observing is possible here. On a platform without POSIX
    signals nothing is installed and the answer is `False`, which a caller can
    report rather than believing a drain will happen that never will. -}
watchForStop :: IO Bool
watchForStop = do
  already <- readIORef watching
  if already
    then pure True
    else install

install :: IO Bool
#if defined(PUDU_POSIX_SIGNALS)
install = do
  let record = Catch (writeIORef requested True)
  _ <- installHandler sigTERM record Nothing
  _ <- installHandler sigINT record Nothing
  writeIORef watching True
  pure True
#else
install = pure False
#endif
