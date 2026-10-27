{-| @Pudu.Compiler.Lower.State — program context, lexical scopes and typed refusals. -}
module Pudu.Compiler.Lower.State
  ( CoreSignature (..), LowerContext (..), LowerState (..), LoopFrame (..)
  , emptyContext, startFunction, refuse, refused, halt, lookupLocal, bindLocal, intType
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Compiler.Lower.Types (LowerTypes)
import Pudu.Core
import Pudu.Diagnostic (Diagnostic)
import Pudu.Diagnostic.Native (nativeRefusal)
import Pudu.Frontend.Syntax (Function, Located)
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

{-| @Compiler.Lower.Context — program-global lowering state: the entry name,
    the top-level function table in declaration order, the signature memo, the
    reachability worklist, the visited set, the refusals collected so far, and
    the functions collected so far. -}
data LowerContext = LowerContext
  { contextTypes :: !LowerTypes
  , contextEntry :: !Text
  , contextTable :: [(Text, Located Function)]
  , contextSignatures :: !(Map Text (Maybe CoreSignature))
  , contextQueue :: ![Text]
  , contextVisited :: !(Set Text)
  , contextRefusals :: ![Diagnostic]
  , contextFunctions :: ![CoreFunction]
  }

{-| @Compiler.Lower.State — one function's lowering state on top of the
    program context: local numbering, the scope stack, and the declared result
    type. The entry starts with no result and records its first explicit
    return; an empty outer block must not erase that return's type. -}
data LowerState = LowerState
  { lowerContext :: !LowerContext
  , lowerNextLocal :: !Int
  , lowerScopes :: ![[(Text, CoreLocal)]]
  , lowerNextLoop :: !Int
  , lowerLoops :: ![LoopFrame]
  , lowerFunctionResult :: !(Maybe CoreType)
  }

{-| A lexical loop destination and the scalar type observed at its breaks.
    Frames survive operand traversal so nested transfers update their target. -}
data LoopFrame = LoopFrame
  { loopIdentity :: !CoreLoopId
  , loopLabel :: !(Maybe Text)
  , loopBreakType :: !(Maybe CoreType)
  }

{-| @Compiler.Lower.Signature — a validated non-entry function: its parameter
    locals (numbered `0..n-1`) and its declared result type. -}
data CoreSignature = CoreSignature
  { signatureParameters :: ![CoreParameter]
  , signatureResult :: !CoreType
  }
  deriving stock (Eq, Show)

emptyContext :: Text -> LowerTypes -> [(Text, Located Function)] -> LowerContext
emptyContext entryName types table =
  LowerContext
    { contextTypes = types
    , contextEntry = entryName
    , contextTable = table
    , contextSignatures = Map.empty
    , contextQueue = []
    , contextVisited = Set.empty
    , contextRefusals = []
    , contextFunctions = []
    }

{-| Begin a function: a fresh scope stack with its parameters bound by name,
    local numbering continuing after them, and its declared result type. -}
startFunction :: LowerState -> [CoreParameter] -> Maybe CoreType -> LowerState
startFunction state parameters resultType =
  state
    { lowerNextLoop = 0
    , lowerLoops = []
    , lowerNextLocal = length parameters
    , lowerScopes =
        [ [ (coreLocalName local, local)
          | parameter <- parameters
          , let local = coreParameterLocal parameter
          ]
        ]
    , lowerFunctionResult = resultType
    }

refuse :: Span -> Text -> LowerState -> LowerState
refuse spanValue construct state =
  state
    { lowerContext =
        context
          { contextRefusals = nativeRefusal spanValue construct : contextRefusals context
          }
    }
  where
    context = lowerContext state

refused :: LowerState -> (LowerState, Maybe a)
refused state = (state, Nothing)

{-| Refuse one construct and stop lowering this subtree, keeping the refusals
    already collected. -}
halt :: Span -> Text -> LowerState -> (LowerState, Maybe a)
halt spanValue construct state = (refuse spanValue construct state, Nothing)

lookupLocal :: LowerState -> Text -> Maybe CoreLocal
lookupLocal state name =
  case [local | frame <- lowerScopes state, (bound, local) <- frame, bound == name] of
    found : _ -> Just found
    [] -> Nothing

bindLocal :: LowerState -> Text -> CoreType -> (LowerState, CoreLocal)
bindLocal state name coreType =
  let local =
        CoreLocal
          { coreLocalId = lowerNextLocal state
          , coreLocalName = name
          , coreLocalType = coreType
          }
   in ( state
          { lowerNextLocal = lowerNextLocal state + 1
          , lowerScopes = case lowerScopes state of
              frame : rest -> ((name, local) : frame) : rest
              [] -> [[(name, local)]]
          }
      , local
      )

intType :: CoreType
intType = CoreIntegerType PlatformSigned
