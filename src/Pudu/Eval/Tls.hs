{-| @Eval.Tls.Module — connections whose contents only the two ends can read

    The protocol itself is not written here, and deliberately not written in
    Pudu either. Transport security is the one place in this library where
    being wrong is silent: a handshake that skips a check still completes, still
    carries traffic, and still looks exactly like one that did not. What makes a
    connection safe is certificate-chain construction, expiry, name matching,
    and version and cipher selection — none of which announce their absence.

    So this reaches an implementation that has been reviewed and attacked for
    years, the same way sockets reach the system's own, and confines this
    module to holding the connection and moving bytes across it. What is
    written here is the part that must not be defaulted: verification is on,
    the system trust store is the source of authority, and the name the caller
    asked for is the name that must be proven. -}
module Pudu.Eval.Tls
  ( TlsStore
  , closeTlsAt
  , closeTlsAtWithin
  , closeTlsStore
  , newTlsStore
  , receiveTls
  , receiveTlsWithin
  , secureConnect
  , secureConnectWithin
  , sendTls
  , sendTlsWithin
  , tlsPeerName
  ) where

import Control.Exception (SomeException, bracketOnError, try)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import Data.Default.Class (def)
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.IntMap.Strict (IntMap)
import qualified Data.IntMap.Strict as IntMap
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Network.Socket as Net
import qualified Network.TLS as Tls
import qualified Network.TLS.Extra.Cipher as Cipher
import Pudu.Eval.Io (IoOutcome (..))
import qualified System.Timeout as Timeout
import qualified System.X509 as X509

{-| One secured connection: the protocol context and the socket beneath it.

    The socket is kept because closing the context does not close it, and a
    connection that released its security but left its socket open would hold a
    descriptor for as long as the program ran. -}
data Secured = Secured
  { securedContext :: !Tls.Context
  , securedSocket :: !Net.Socket
  , securedHost :: !Text
  }

data TlsStore = TlsStore
  { tlsTable :: !(IORef (IntMap Secured))
  , tlsNextToken :: !(IORef Int)
  }

newTlsStore :: IO TlsStore
newTlsStore = TlsStore <$> newIORef IntMap.empty <*> newIORef 1

remember :: TlsStore -> Secured -> IO Int
remember store secured = do
  token <- atomicModifyIORef' (tlsNextToken store) (\value -> (value + 1, value))
  atomicModifyIORef' (tlsTable store) (\table -> (IntMap.insert token secured table, ()))
  pure token

lookupSecured :: TlsStore -> Int -> IO (Maybe Secured)
lookupSecured store token = IntMap.lookup token <$> readIORef (tlsTable store)

{-| Open a connection and prove the far end is who the caller asked for.

    Verification is not an option this takes. A caller who could turn it off
    would eventually turn it off to make something work, and the result is a
    connection that is encrypted against a stranger rather than private with
    the intended server — which is worse than a plain one, because it looks
    secure. Trust comes from the system's own store, so a machine that has been
    told about an internal authority is believed and this module does not keep
    a list of its own to go stale.

    The name checked is the one the caller named, not one the certificate
    offers. Letting the certificate choose is how a valid certificate for one
    host is accepted for another. -}
secureConnect :: TlsStore -> Text -> Int -> IO (IoOutcome Int)
secureConnect store host port = secureConnectWithin store host port (-1)

{-| Open and verify a connection within one operation budget. A negative
    budget retains the unbounded low-level primitive. -}
secureConnectWithin :: TlsStore -> Text -> Int -> Integer -> IO (IoOutcome Int)
secureConnectWithin store host port millis = do
  attempted <- attemptWithin millis $ do
    resolved <- resolveAddressRaw (Text.unpack host) port
    case resolved of
      Left problem -> pure (Left problem)
      Right address -> Right <$> openSecured address
  case attempted of
    Left problem -> pure (IoFailed (Text.pack (show problem)))
    Right Nothing -> pure (IoFailed timeoutMessage)
    Right (Just (Left problem)) -> pure (IoFailed problem)
    Right (Just (Right secured)) -> IoDone <$> remember store secured
 where
  openSecured address =
    bracketOnError (Net.openSocket address) Net.close $ \socket -> do
      Net.connect socket (Net.addrAddress address)
      trust <- X509.getSystemCertificateStore
      context <- Tls.contextNew socket (parameters trust)
      Tls.handshake context
      pure Secured{securedContext = context, securedSocket = socket, securedHost = host}

  parameters trust =
    (Tls.defaultParamsClient (Text.unpack host) mempty)
      { Tls.clientSupported = def{Tls.supportedCiphers = Cipher.ciphersuite_strong}
      , Tls.clientShared = def{Tls.sharedCAStore = trust}
      }

resolveAddressRaw :: String -> Int -> IO (Either Text Net.AddrInfo)
resolveAddressRaw host port = do
  let hints = Net.defaultHints{Net.addrSocketType = Net.Stream}
  found <- Net.getAddrInfo (Just hints) (Just host) (Just (show port))
  pure $ case found of
    [] -> Left (Text.pack ("no address for " <> host <> ":" <> show port))
    address : _ -> Right address

{-| Send bytes, and keep sending until every one of them has gone. -}
sendTls :: TlsStore -> Int -> ByteString.ByteString -> IO (IoOutcome ())
sendTls store token payload = sendTlsWithin store token payload (-1)

sendTlsWithin :: TlsStore -> Int -> ByteString.ByteString -> Integer -> IO (IoOutcome ())
sendTlsWithin store token payload millis = do
  found <- lookupSecured store token
  case found of
    Nothing -> pure (IoFailed "the secured connection is closed")
    Just secured -> do
      attempted <- attemptWithin millis (Tls.sendData (securedContext secured) (LazyByteString.fromStrict payload))
      case attempted of
        Left problem -> pure (IoFailed (Text.pack (show problem)))
        Right Nothing -> invalidateTls store token >> pure (IoFailed timeoutMessage)
        Right (Just ()) -> pure (IoDone ())

{-| The next bytes, or nothing when the far end has finished.

    The count a caller asks for is not a promise: the protocol hands over whole
    records, so what arrives is what one record held. A caller needing an exact
    number reads until it has them, exactly as over a plain connection. -}
receiveTls :: TlsStore -> Int -> Int -> IO (IoOutcome (Maybe ByteString.ByteString))
receiveTls store token count = receiveTlsWithin store token count (-1)

receiveTlsWithin :: TlsStore -> Int -> Int -> Integer -> IO (IoOutcome (Maybe ByteString.ByteString))
receiveTlsWithin store token count millis
  | count <= 0 = pure (IoDone (Just ByteString.empty))
  | otherwise = do
      found <- lookupSecured store token
      case found of
        Nothing -> pure (IoFailed "the secured connection is closed")
        Just secured -> do
          attempted <- attemptWithin millis (Tls.recvData (securedContext secured))
          case attempted of
            Left problem -> pure (IoFailed (Text.pack (show problem)))
            Right Nothing -> invalidateTls store token >> pure (IoFailed timeoutMessage)
            Right (Just chunk)
              | ByteString.null chunk -> pure (IoDone Nothing)
              | otherwise -> pure (IoDone (Just chunk))

{-| The name this connection was opened against, which is the name that was
    proven rather than whatever the certificate happened to offer. -}
tlsPeerName :: TlsStore -> Int -> IO (IoOutcome Text)
tlsPeerName store token = withSecured store token (pure . IoDone . securedHost)

{-| Say the connection is finished, then close what carried it.

    The protocol's own goodbye goes first so the far end learns the connection
    ended rather than inferring it from a socket that stopped answering, which
    it cannot tell from an attacker cutting the line. -}
closeTlsAt :: TlsStore -> Int -> IO (IoOutcome ())
closeTlsAt store token = closeTlsAtWithin store token (-1)

closeTlsAtWithin :: TlsStore -> Int -> Integer -> IO (IoOutcome ())
closeTlsAtWithin store token millis = do
  taken <-
    atomicModifyIORef' (tlsTable store) $ \table ->
      (IntMap.delete token table, IntMap.lookup token table)
  case taken of
    Nothing -> pure (IoDone ())
    Just secured -> do
      farewell <- attemptWithin millis (Tls.bye (securedContext secured))
      _ <- try (Net.close (securedSocket secured)) :: IO (Either SomeException ())
      pure $ case farewell of
        Right Nothing -> IoFailed timeoutMessage
        _ -> IoDone ()

{-| Close every connection the run still holds. -}
closeTlsStore :: TlsStore -> IO ()
closeTlsStore store = do
  table <- atomicModifyIORef' (tlsTable store) (\current -> (IntMap.empty, current))
  mapM_ stopQuietly (IntMap.elems table)
 where
  stopQuietly secured = do
    _ <- try (releaseQuietly secured) :: IO (Either SomeException ())
    pure ()

{-| A goodbye that cannot itself fail the close.

    A far end that has already gone makes the notification fail, and reporting
    that as a failure to close would make an ordinary ending look like a
    fault. The socket is closed either way. -}
releaseQuietly :: Secured -> IO ()
releaseQuietly secured = do
  _ <- try (Tls.bye (securedContext secured)) :: IO (Either SomeException ())
  _ <- try (Net.close (securedSocket secured)) :: IO (Either SomeException ())
  pure ()

withSecured :: TlsStore -> Int -> (Secured -> IO (IoOutcome a)) -> IO (IoOutcome a)
withSecured store token action = do
  found <- lookupSecured store token
  case found of
    Nothing -> pure (IoFailed "the secured connection is closed")
    Just secured -> action secured

attemptWithin :: Integer -> IO a -> IO (Either SomeException (Maybe a))
attemptWithin millis action
  | millis < 0 = fmap (fmap Just) (try action)
  | otherwise = try (Timeout.timeout (microseconds millis) action)

microseconds :: Integer -> Int
microseconds millis =
  fromInteger (min (toInteger (maxBound :: Int)) (max 0 millis * 1000))

timeoutMessage :: Text
timeoutMessage = "operation timed out"

invalidateTls :: TlsStore -> Int -> IO ()
invalidateTls store token = do
  taken <-
    atomicModifyIORef' (tlsTable store) $ \table ->
      (IntMap.delete token table, IntMap.lookup token table)
  case taken of
    Nothing -> pure ()
    Just secured -> do
      _ <- try (Net.close (securedSocket secured)) :: IO (Either SomeException ())
      pure ()
