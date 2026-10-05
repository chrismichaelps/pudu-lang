{-# LANGUAGE MagicHash, UnboxedSums, UnboxedTuples #-}
{-| @Eval.Loop.Step — strict region outcomes without per-expression boxing. -}
module Pudu.Eval.Loop.Step
  ( Step
  , liftStep
  , stopStep
  , runStep
  , finallyStep
  ) where

import GHC.Exts (RealWorld, State#)
import GHC.IO (IO (..))
import Pudu.Eval.Env (Eval)
import Pudu.Eval.Value (Value)

{-| Only the complete-region proof permits an operation to omit Env threading.
    Both alternatives retain the old strict outcome boundary. -}
newtype Step a = Step (State# RealWorld -> (# State# RealWorld, (# a | Eval Value #) #))

instance Functor Step where
  {-# INLINE fmap #-}
  fmap transform operation = operation >>= pure . transform

instance Applicative Step where
  {-# INLINE pure #-}
  pure value = Step $ \state -> value `seq` (# state, (# value | #) #)
  {-# INLINE (<*>) #-}
  left <*> right = left >>= \transform -> fmap transform right

instance Monad Step where
  {-# INLINE (>>=) #-}
  Step action >>= next = Step $ \state -> case action state of
    (# after, (# value | #) #) -> case next value of
      Step continued -> continued after
    (# after, (# | stopped #) #) -> (# after, (# | stopped #) #)

{-# INLINE liftStep #-}
liftStep :: IO a -> Step a
liftStep (IO action) = Step $ \state -> case action state of
  (# after, value #) -> value `seq` (# after, (# value | #) #)

{-# INLINE stopStep #-}
stopStep :: Eval Value -> Step a
stopStep stopped = Step $ \state -> stopped `seq` (# state, (# | stopped #) #)

{-| Box once at the region boundary, after all planned operations finish. -}
runStep :: Step a -> IO (Either (Eval Value) a)
runStep (Step action) = IO $ \state -> case action state of
  (# after, (# value | #) #) -> (# after, Right value #)
  (# after, (# | stopped #) #) -> (# after, Left stopped #)

{-| Scratch clears on a structured refusal as well as on success. -}
{-# INLINE finallyStep #-}
finallyStep :: Step a -> IO () -> Step a
finallyStep (Step action) (IO cleanup) = Step $ \state -> case action state of
  (# after, outcome #) -> case cleanup after of
    (# finished, () #) -> (# finished, outcome #)
