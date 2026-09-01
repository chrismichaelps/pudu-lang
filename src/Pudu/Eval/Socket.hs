{-| @Eval.Socket.Module — network endpoints the program has open -}
module Pudu.Eval.Socket
  ( acceptOn
  , closeAllSockets
  , closeSocketAt
  , connectTo
  , listenOn
  , localPortOf
  , peerOf
  , receiveFrom
  , sendOn
  , shutdownWriteAt
  ) where

import Control.Exception (IOException, SomeException, bracketOnError, try)
import qualified Data.ByteString as ByteString
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.IntMap.Strict (IntMap)
import qualified Data.IntMap.Strict as IntMap
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Network.Socket as Net
import qualified Network.Socket.ByteString as NetBytes
import Pudu.Eval.Io (IoOutcome (..))
import System.IO.Unsafe (unsafePerformIO)

{-| Every endpoint the program has open, keyed by the token it holds.

    Process-wide for the reason open files are: an endpoint is one object with
    one position in its stream, while the evaluation environment is threaded
    and copied, so a socket opened down one branch has to be closable from
    every other. -}
socketTable :: IORef (IntMap Net.Socket)
{-# NOINLINE socketTable #-}
socketTable = unsafePerformIO (newIORef IntMap.empty)

{-| Tokens are never reused, so a program holding a stale one cannot reach an
    endpoint opened later by something else. -}
nextToken :: IORef Int
{-# NOINLINE nextToken #-}
nextToken = unsafePerformIO (newIORef 1)

remember :: Net.Socket -> IO Int
remember socket = do
  token <- atomicModifyIORef' nextToken (\value -> (value + 1, value))
  atomicModifyIORef' socketTable (\table -> (IntMap.insert token socket table, ()))
  pure token

lookupSocket :: Int -> IO (Maybe Net.Socket)
lookupSocket token = IntMap.lookup token <$> readIORef socketTable

{-| The address a host and port name.

    Asked of the resolver rather than parsed here, so a name, a numeric
    address, and either family of address all arrive the same way. A library
    that read the text itself would have to decide what a name meant, which is
    a question only the machine's own configuration can answer. -}
addressFor :: Bool -> String -> Int -> IO (Either Text Net.AddrInfo)
addressFor passive host port = do
  let hints =
        Net.defaultHints
          { Net.addrSocketType = Net.Stream
          , Net.addrFlags = if passive then [Net.AI_PASSIVE] else []
          }
      wanted = if passive && null host then Nothing else Just host
  found <-
    try (Net.getAddrInfo (Just hints) wanted (Just (show port)))
      :: IO (Either SomeException [Net.AddrInfo])
  pure $ case found of
    Left problem -> Left (Text.pack (show problem))
    Right [] -> Left (Text.pack ("no address for " <> host <> ":" <> show port))
    Right (address : _) -> Right address

{-| Open an endpoint that waits for connections.

    The address is marked reusable before it is bound. Without that, an
    endpoint that has just closed keeps its port reserved while the operating
    system waits out the connections that may still be in flight, and a server
    restarted inside that window cannot bind the port it just had. -}
listenOn :: Text -> Int -> Int -> IO (IoOutcome Int)
listenOn host port backlog = do
  resolved <- addressFor True (Text.unpack host) port
  case resolved of
    Left problem -> pure (IoFailed problem)
    Right address -> do
      attempted <-
        try
          ( bracketOnError
              (Net.openSocket address)
              Net.close
              ( \socket -> do
                  Net.setSocketOption socket Net.ReuseAddr 1
                  Net.bind socket (Net.addrAddress address)
                  Net.listen socket backlog
                  pure socket
              )
          )
          :: IO (Either SomeException Net.Socket)
      case attempted of
        Left problem -> pure (IoFailed (Text.pack (show problem)))
        Right socket -> IoDone <$> remember socket

{-| Wait for the next connection and answer the token naming it. -}
acceptOn :: Int -> IO (IoOutcome Int)
acceptOn token = withSocket token $ \socket -> do
  attempted <- try (Net.accept socket) :: IO (Either SomeException (Net.Socket, Net.SockAddr))
  case attempted of
    Left problem -> pure (IoFailed (Text.pack (show problem)))
    Right (connection, _) -> IoDone <$> remember connection

{-| Open a connection to somewhere else. -}
connectTo :: Text -> Int -> IO (IoOutcome Int)
connectTo host port = do
  resolved <- addressFor False (Text.unpack host) port
  case resolved of
    Left problem -> pure (IoFailed problem)
    Right address -> do
      attempted <-
        try
          ( bracketOnError
              (Net.openSocket address)
              Net.close
              (\socket -> Net.connect socket (Net.addrAddress address) >> pure socket)
          )
          :: IO (Either SomeException Net.Socket)
      case attempted of
        Left problem -> pure (IoFailed (Text.pack (show problem)))
        Right socket -> IoDone <$> remember socket

{-| Send bytes, and keep sending until every one of them has gone.

    A single write is permitted to take fewer bytes than it was offered, so a
    sender that wrote once and moved on would silently truncate exactly the
    large messages it was most important not to. -}
sendOn :: Int -> ByteString.ByteString -> IO (IoOutcome ())
sendOn token payload = withSocket token $ \socket -> do
  attempted <- try (NetBytes.sendAll socket payload) :: IO (Either SomeException ())
  pure $ case attempted of
    Left problem -> IoFailed (Text.pack (show problem))
    Right () -> IoDone ()

{-| Read at most the requested count of bytes.

    Nothing means the other end has closed and will send no more, which is a
    different answer from an empty read: a reader that could not tell them
    apart would either stop on a slow peer or never stop on a finished one. -}
receiveFrom :: Int -> Int -> IO (IoOutcome (Maybe ByteString.ByteString))
receiveFrom token count
  | count <= 0 = pure (IoDone (Just ByteString.empty))
  | otherwise = withSocket token $ \socket -> do
      attempted <-
        try (NetBytes.recv socket count)
          :: IO (Either SomeException ByteString.ByteString)
      pure $ case attempted of
        Left problem -> IoFailed (Text.pack (show problem))
        Right chunk
          | ByteString.null chunk -> IoDone Nothing
          | otherwise -> IoDone (Just chunk)

{-| Say that nothing more will be sent, while still reading what arrives.

    This is what tells the other end that a request is complete where the
    protocol marks the end of a message by the sender closing. Closing outright
    would also discard the reply. -}
shutdownWriteAt :: Int -> IO (IoOutcome ())
shutdownWriteAt token = withSocket token $ \socket -> do
  attempted <- try (Net.shutdown socket Net.ShutdownSend) :: IO (Either IOException ())
  pure $ case attempted of
    Left problem -> IoFailed (Text.pack (show problem))
    Right () -> IoDone ()

{-| Who is at the other end, as text. -}
peerOf :: Int -> IO (IoOutcome Text)
peerOf token = withSocket token $ \socket -> do
  attempted <- try (Net.getPeerName socket) :: IO (Either SomeException Net.SockAddr)
  pure $ case attempted of
    Left problem -> IoFailed (Text.pack (show problem))
    Right address -> IoDone (Text.pack (show address))

{-| Which port an endpoint is actually on.

    Binding to port zero asks the operating system to choose one, which is how
    a test starts a server without picking a number that something else on the
    machine may already hold. The choice is only knowable by asking. -}
localPortOf :: Int -> IO (IoOutcome Int)
localPortOf token = withSocket token $ \socket -> do
  attempted <- try (Net.getSocketName socket) :: IO (Either SomeException Net.SockAddr)
  pure $ case attempted of
    Left problem -> IoFailed (Text.pack (show problem))
    Right address -> pure' (portOf address)
 where
  pure' found = case found of
    Just port -> IoDone port
    Nothing -> IoFailed "the endpoint has no port"

portOf :: Net.SockAddr -> Maybe Int
portOf address = case address of
  Net.SockAddrInet port _ -> Just (fromIntegral port)
  Net.SockAddrInet6 port _ _ _ -> Just (fromIntegral port)
  _ -> Nothing

{-| Close an endpoint and forget its token.

    Closing one already closed is not a failure, for the reason a bracket's
    close is not: a caller who closed early should not be reported against for
    the scope doing what it promised. -}
closeSocketAt :: Int -> IO (IoOutcome ())
closeSocketAt token = do
  taken <-
    atomicModifyIORef' socketTable $ \table ->
      (IntMap.delete token table, IntMap.lookup token table)
  case taken of
    Nothing -> pure (IoDone ())
    Just socket -> do
      attempted <- try (Net.close socket) :: IO (Either SomeException ())
      pure $ case attempted of
        Left problem -> IoFailed (Text.pack (show problem))
        Right () -> IoDone ()

{-| Close everything still open, so a program that ended holding an endpoint
    releases the port rather than leaving it held until the process is reaped. -}
closeAllSockets :: IO ()
closeAllSockets = do
  table <- atomicModifyIORef' socketTable (\current -> (IntMap.empty, current))
  mapM_ closeQuietly (IntMap.elems table)
 where
  closeQuietly socket = do
    _ <- try (Net.close socket) :: IO (Either SomeException ())
    pure ()

withSocket :: Int -> (Net.Socket -> IO (IoOutcome a)) -> IO (IoOutcome a)
withSocket token action = do
  found <- lookupSocket token
  case found of
    Nothing -> pure (IoFailed "the endpoint is closed")
    Just socket -> action socket
