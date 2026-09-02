{-| @Eval.Socket.Module — network endpoints the program has open -}
module Pudu.Eval.Socket
  ( SocketStore
  , acceptOn
  , closeSocketStore
  , closeSocketAt
  , connectTo
  , connectToWithin
  , listenOn
  , localPortOf
  , newSocketStore
  , peerOf
  , receiveFrom
  , receiveFromWithin
  , sendOn
  , sendOnWithin
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
import qualified System.Timeout as Timeout

{-| Every endpoint one evaluation has open. The store is shared by captured
    frames and child threads but never by independent evaluations. -}
data SocketStore = SocketStore
  { socketTable :: !(IORef (IntMap Net.Socket))
  , socketNextToken :: !(IORef Int)
  }

newSocketStore :: IO SocketStore
newSocketStore = SocketStore <$> newIORef IntMap.empty <*> newIORef 1

remember :: SocketStore -> Net.Socket -> IO Int
remember store socket = do
  token <- atomicModifyIORef' (socketNextToken store) (\value -> (value + 1, value))
  atomicModifyIORef' (socketTable store) (\table -> (IntMap.insert token socket table, ()))
  pure token

lookupSocket :: SocketStore -> Int -> IO (Maybe Net.Socket)
lookupSocket store token = IntMap.lookup token <$> readIORef (socketTable store)

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
listenOn :: SocketStore -> Text -> Int -> Int -> IO (IoOutcome Int)
listenOn store host port backlog = do
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
        Right socket -> IoDone <$> remember store socket

{-| Wait for the next connection and answer the token naming it. -}
acceptOn :: SocketStore -> Int -> IO (IoOutcome Int)
acceptOn store token = withSocket store token $ \socket -> do
  attempted <- try (Net.accept socket) :: IO (Either SomeException (Net.Socket, Net.SockAddr))
  case attempted of
    Left problem -> pure (IoFailed (Text.pack (show problem)))
    Right (connection, _) -> IoDone <$> remember store connection

{-| Open a connection to somewhere else. -}
connectTo :: SocketStore -> Text -> Int -> IO (IoOutcome Int)
connectTo store host port = connectToWithin store host port (-1)

{-| Open a connection, interrupting resolution or connection when the operation
    budget is exhausted. A negative budget retains the unbounded primitive. -}
connectToWithin :: SocketStore -> Text -> Int -> Integer -> IO (IoOutcome Int)
connectToWithin store host port millis = do
  attempted <- attemptWithin millis $ do
    resolved <- addressForRaw False (Text.unpack host) port
    case resolved of
      Left problem -> pure (Left problem)
      Right address ->
        Right
          <$> bracketOnError
            (Net.openSocket address)
            Net.close
            (\socket -> Net.connect socket (Net.addrAddress address) >> pure socket)
  case attempted of
    Left problem -> pure (IoFailed (Text.pack (show problem)))
    Right Nothing -> pure (IoFailed timeoutMessage)
    Right (Just (Left problem)) -> pure (IoFailed problem)
    Right (Just (Right socket)) -> IoDone <$> remember store socket

{-| Send bytes, and keep sending until every one of them has gone.

    A single write is permitted to take fewer bytes than it was offered, so a
    sender that wrote once and moved on would silently truncate exactly the
    large messages it was most important not to. -}
sendOn :: SocketStore -> Int -> ByteString.ByteString -> IO (IoOutcome ())
sendOn store token payload = sendOnWithin store token payload (-1)

sendOnWithin :: SocketStore -> Int -> ByteString.ByteString -> Integer -> IO (IoOutcome ())
sendOnWithin store token payload millis = do
  found <- lookupSocket store token
  case found of
    Nothing -> pure (IoFailed "the endpoint is closed")
    Just socket -> do
      attempted <- attemptWithin millis (NetBytes.sendAll socket payload)
      case attempted of
        Left problem -> pure (IoFailed (Text.pack (show problem)))
        Right Nothing -> invalidateSocket store token >> pure (IoFailed timeoutMessage)
        Right (Just ()) -> pure (IoDone ())

{-| Read at most the requested count of bytes.

    Nothing means the other end has closed and will send no more, which is a
    different answer from an empty read: a reader that could not tell them
    apart would either stop on a slow peer or never stop on a finished one. -}
receiveFrom :: SocketStore -> Int -> Int -> IO (IoOutcome (Maybe ByteString.ByteString))
receiveFrom store token count = receiveFromWithin store token count (-1)

receiveFromWithin :: SocketStore -> Int -> Int -> Integer -> IO (IoOutcome (Maybe ByteString.ByteString))
receiveFromWithin store token count millis
  | count <= 0 = pure (IoDone (Just ByteString.empty))
  | otherwise = do
      found <- lookupSocket store token
      case found of
        Nothing -> pure (IoFailed "the endpoint is closed")
        Just socket -> do
          attempted <- attemptWithin millis (NetBytes.recv socket count)
          case attempted of
            Left problem -> pure (IoFailed (Text.pack (show problem)))
            Right Nothing -> invalidateSocket store token >> pure (IoFailed timeoutMessage)
            Right (Just chunk)
              | ByteString.null chunk -> pure (IoDone Nothing)
              | otherwise -> pure (IoDone (Just chunk))

{-| Say that nothing more will be sent, while still reading what arrives.

    This is what tells the other end that a request is complete where the
    protocol marks the end of a message by the sender closing. Closing outright
    would also discard the reply. -}
shutdownWriteAt :: SocketStore -> Int -> IO (IoOutcome ())
shutdownWriteAt store token = withSocket store token $ \socket -> do
  attempted <- try (Net.shutdown socket Net.ShutdownSend) :: IO (Either IOException ())
  pure $ case attempted of
    Left problem -> IoFailed (Text.pack (show problem))
    Right () -> IoDone ()

{-| Who is at the other end, as text. -}
peerOf :: SocketStore -> Int -> IO (IoOutcome Text)
peerOf store token = withSocket store token $ \socket -> do
  attempted <- try (Net.getPeerName socket) :: IO (Either SomeException Net.SockAddr)
  pure $ case attempted of
    Left problem -> IoFailed (Text.pack (show problem))
    Right address -> IoDone (Text.pack (show address))

{-| Which port an endpoint is actually on.

    Binding to port zero asks the operating system to choose one, which is how
    a test starts a server without picking a number that something else on the
    machine may already hold. The choice is only knowable by asking. -}
localPortOf :: SocketStore -> Int -> IO (IoOutcome Int)
localPortOf store token = withSocket store token $ \socket -> do
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
closeSocketAt :: SocketStore -> Int -> IO (IoOutcome ())
closeSocketAt store token = do
  taken <-
    atomicModifyIORef' (socketTable store) $ \table ->
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
closeSocketStore :: SocketStore -> IO ()
closeSocketStore store = do
  table <- atomicModifyIORef' (socketTable store) (\current -> (IntMap.empty, current))
  mapM_ closeQuietly (IntMap.elems table)
 where
  closeQuietly socket = do
    _ <- try (Net.close socket) :: IO (Either SomeException ())
    pure ()

withSocket :: SocketStore -> Int -> (Net.Socket -> IO (IoOutcome a)) -> IO (IoOutcome a)
withSocket store token action = do
  found <- lookupSocket store token
  case found of
    Nothing -> pure (IoFailed "the endpoint is closed")
    Just socket -> action socket

addressForRaw :: Bool -> String -> Int -> IO (Either Text Net.AddrInfo)
addressForRaw passive host port = do
  let hints =
        Net.defaultHints
          { Net.addrSocketType = Net.Stream
          , Net.addrFlags = if passive then [Net.AI_PASSIVE] else []
          }
      wanted = if passive && null host then Nothing else Just host
  found <- Net.getAddrInfo (Just hints) wanted (Just (show port))
  pure $ case found of
    [] -> Left (Text.pack ("no address for " <> host <> ":" <> show port))
    address : _ -> Right address

attemptWithin :: Integer -> IO a -> IO (Either SomeException (Maybe a))
attemptWithin millis action
  | millis < 0 = fmap (fmap Just) (try action)
  | otherwise = try (Timeout.timeout (microseconds millis) action)

microseconds :: Integer -> Int
microseconds millis =
  fromInteger (min (toInteger (maxBound :: Int)) (max 0 millis * 1000))

timeoutMessage :: Text
timeoutMessage = "operation timed out"

invalidateSocket :: SocketStore -> Int -> IO ()
invalidateSocket store token = do
  _ <- closeSocketAt store token
  pure ()
