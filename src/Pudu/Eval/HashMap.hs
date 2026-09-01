{-| @Eval.HashMap.Module — the indexed store a hash map reaches its buckets through

    [[ADR-0015]] settles what `Std.HashMap` needs and what it may not be built
    from. Buckets held in the ordered `Map` would make every lookup an ordered
    lookup plus collision work, which is the container the hash map exists to
    improve on. What is missing is a store reached by a number rather than by
    comparison, and that is the whole of what this module adds.

    The store is keyed by a number and holds any value. It knows nothing about
    hashing, equality, or order: `Std.HashMap` computes the key's hash, decides
    identity with the caller's own `Eq`, and keeps insertion order itself. That
    split is what lets collisions be resolved by the equality a type declared
    rather than by the structural equality the runtime happens to have — the
    two differ exactly when a type defines what it means to be the same value,
    which is when getting it wrong matters. -}
module Pudu.Eval.HashMap
  ( callBucketsMethod
  , callBucketsOf
  , mixKey
  , bucketsMethods
  ) where

import Data.Bits (shiftL, shiftR, xor)
import qualified Data.IntMap.Strict as IntMap
import qualified Data.ByteString as ByteString
import Data.IORef (IORef, newIORef, readIORef)
import qualified Data.Sequence as Seq
import Data.Text (Text)
import Data.Word (Word64)
import Pudu.Eval.Entropy (secureBytes)
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Io (IoOutcome (..))
import Pudu.Eval.Value
  ( BucketsMethod (..)
  , Value (..)
  , intOf
  , bucketsMethodName
  )
import Pudu.Source (Span)
import System.IO.Unsafe (unsafePerformIO)

{-| A number mixed once more before it selects a bucket, against a value chosen
    when the process started.

    A hash a caller can predict is a hash an attacker can repeat: sending many
    keys that land in one bucket turns every lookup into a walk of that bucket,
    and a server keying a map on what it was sent is where that is done. The
    seed makes the placement differ between processes without changing what
    any key is equal to.

    It is deliberately not observable. Iteration order is insertion order,
    which `Std.HashMap` keeps for itself, so nothing a program can print
    depends on where a bucket happened to land. -}
bucketSeed :: IORef Word64
{-# NOINLINE bucketSeed #-}
bucketSeed = unsafePerformIO (newIORef =<< startingSeed)

{-| The seed a run starts from, taken from the operating system.

    Asked of the same provider a key is, because a seed a caller could predict
    would not resist the thing it exists to resist. Where the provider cannot
    answer the seed falls back to a fixed value rather than refusing to start:
    a map that would not work at all is worse than one whose bucket placement
    is guessable, and the placement is not what keeps anything secret. -}
startingSeed :: IO Word64
startingSeed = do
  drawn <- secureBytes 8
  pure $ case drawn of
    IoDone bytes | ByteString.length bytes == 8 -> ByteString.foldl' pack 0 bytes
    _ -> 0x9e3779b97f4a7c15
 where
  pack accumulated byte = (accumulated `shiftL` 8) + fromIntegral byte

{-| Spread a hash across the whole word before its low bits pick a bucket.

    A hash that is well behaved in its high bits and dull in its low ones is
    common — a counter, a small integer, a pointer — and the low bits are the
    ones a bucket index reads. Mixing moves every input bit into every output
    bit, so a key that differs anywhere lands somewhere else. -}
mixKey :: Integer -> Integer
mixKey value = fromIntegral (finalize (fromIntegral value `xor` seed))
 where
  seed = unsafePerformIO (readIORef bucketSeed)
  finalize :: Word64 -> Word64
  finalize start =
    let a = (start `xor` (start `shiftR` 30)) * 0xbf58476d1ce4e5b9
        b = (a `xor` (a `shiftR` 27)) * 0x94d049bb133111eb
     in b `xor` (b `shiftR` 31)

{-| An empty store. -}
callBucketsOf :: Span -> [Value] -> Evaluator Value
callBucketsOf spanValue arguments = case arguments of
  [] -> pure (BucketsValue IntMap.empty)
  _ -> abortAt (Just spanValue) "E7003" "bucketsOf takes no arguments" Nothing

{-| The methods a store carries, paired with their tags. -}
bucketsMethods :: [(Text, BucketsMethod)]
bucketsMethods =
  [ ("size", BucketsSize)
  , ("isEmpty", BucketsIsEmpty)
  , ("get", BucketsGet)
  , ("insert", BucketsInsert)
  , ("remove", BucketsRemove)
  , ("keys", BucketsKeys)
  , ("values", BucketsValues)
  ]

{-| Apply one built-in store method.

    Every one answers with a new store rather than changing the one it was
    given, like every other collection in the language. A store is reached by
    a number whose width bounds the work, so a lookup costs the same whether
    the store holds ten entries or ten million — which is the property the
    ordered map cannot offer and the reason this exists. -}
callBucketsMethod :: Span -> BucketsMethod -> Value -> [Value] -> Evaluator Value
callBucketsMethod spanValue method receiver arguments = case receiver of
  BucketsValue entries -> apply entries
  _ -> abortAt (Just spanValue) "E7001" "not an indexed store" Nothing
 where
  apply entries = case (method, arguments) of
    (BucketsSize, []) -> pure (intOf (fromIntegral (IntMap.size entries)))
    (BucketsIsEmpty, []) -> pure (BoolValue (IntMap.null entries))
    (BucketsGet, [IntValue _ key]) -> case IntMap.lookup (narrow key) entries of
      Just found -> pure (VariantValue "Some" [found])
      Nothing -> pure (VariantValue "None" [])
    (BucketsInsert, [IntValue _ key, value]) ->
      pure (BucketsValue (IntMap.insert (narrow key) value entries))
    (BucketsRemove, [IntValue _ key]) ->
      pure (BucketsValue (IntMap.delete (narrow key) entries))
    (BucketsKeys, []) ->
      pure (ArrayValue (Seq.fromList (map (intOf . fromIntegral) (IntMap.keys entries))))
    (BucketsValues, []) -> pure (ArrayValue (Seq.fromList (IntMap.elems entries)))
    _ ->
      abortAt (Just spanValue) "E7003"
        ("wrong arguments for store method " <> bucketsMethodName method) Nothing

  {-| A key wider than the machine's word is folded into one rather than
      refused. Two keys that fold together are a collision, which the caller's
      own equality already has to settle, so nothing is lost that the bucket
      walk does not already handle. -}
  narrow :: Integer -> Int
  narrow = fromIntegral
