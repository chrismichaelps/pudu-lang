{-| @Comptime.Limits — phase-neutral bounds on compile-time work. -}
module Pudu.Comptime.Limits
  ( callDepthLimit, expansionNodeLimit, iterationLimit ) where

callDepthLimit :: Int
callDepthLimit = 4096

iterationLimit :: Int
iterationLimit = 100000

expansionNodeLimit :: Int
expansionNodeLimit = 1000000
