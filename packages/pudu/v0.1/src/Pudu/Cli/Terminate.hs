{-# LANGUAGE CPP #-}

{-| @Program.Cli.Terminate — a request to stop, taken the way Ctrl-C is

    A command that starts another process and stops it when it is done — the
    watch loop is one — stops it from the cleanup around it. Ctrl-C reaches
    that cleanup: the terminal signals every process in the group, and the
    runtime raises the interrupt in the main thread, which unwinds through it.
    `SIGTERM` does not. It is what a supervisor, an editor, or a launcher sends,
    and by default it ends the process where it stands, so the process it
    started is left running — still holding a port, which is how the next start
    fails as though the program were wrong. -}
module Pudu.Cli.Terminate (interruptOnTerminate) where

#if defined(PUDU_POSIX_SIGNALS)
import Control.Concurrent (myThreadId)
import Control.Exception (AsyncException (UserInterrupt), throwTo)
import System.Posix.Signals (Handler (Catch), installHandler, sigTERM)
#endif

{-| From now on, take `SIGTERM` as the interrupt Ctrl-C raises, in the thread
    that calls this, so the cleanup that thread is inside runs. Nothing happens
    on a platform without POSIX signals, where there is no `SIGTERM` to take. -}
interruptOnTerminate :: IO ()
#if defined(PUDU_POSIX_SIGNALS)
interruptOnTerminate = do
  caller <- myThreadId
  _ <- installHandler sigTERM (Catch (throwTo caller UserInterrupt)) Nothing
  pure ()
#else
interruptOnTerminate = pure ()
#endif
