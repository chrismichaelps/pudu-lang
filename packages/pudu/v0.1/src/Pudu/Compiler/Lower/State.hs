{-| @Pudu.Compiler.Lower.State — program context, lexical scopes and typed refusals. -}
module Pudu.Compiler.Lower.State
  ( CoreSignature (..), LowerContext (..), LowerState (..), LoopFrame (..), ModuleScope (..)
  , emptyContext, startFunction, refuse, refused, halt, lookupLocal, bindLocal, intType
  , resolveFunction, inModule, isModuleQualifier
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Compiler.Lower.Types (LowerTypes, emptyTypes)
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
  {-| Every module's functions by canonical name (`Module.function`), each
      beside the module it belongs to. -}
  , contextTable :: [(Text, (Text, Located Function))]
  , contextModules :: !(Map Text ModuleScope)
  {-| The module whose function is being lowered; names resolve in it. -}
  , contextModule :: !Text
  , contextSignatures :: !(Map Text (Maybe CoreSignature))
  , contextQueue :: ![Text]
  , contextVisited :: !(Set Text)
  , contextRefusals :: ![Diagnostic]
  , contextFunctions :: ![CoreFunction]
  }

{-| What one module's names mean: its checked facts, the functions it
    declares, the names it imports selectively, and the qualifiers it reaches
    other modules through. -}
data ModuleScope = ModuleScope
  { scopeTypes :: !LowerTypes
  , scopeFunctions :: !(Set Text)
  {-| A selectively imported name and the module it comes from. -}
  , scopeSelected :: !(Map Text Text)
  {-| A qualifier (an alias, or the module path's last segment) and its module. -}
  , scopeQualifiers :: !(Map Text Text)
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

emptyContext :: Text -> Text -> Map Text ModuleScope -> [(Text, (Text, Located Function))] -> LowerContext
emptyContext root entryName modules table =
  LowerContext
    { contextTypes = maybe emptyTypes scopeTypes (Map.lookup root modules)
    , contextEntry = entryName
    , contextTable = table
    , contextModules = modules
    , contextModule = root
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

{-| The canonical function a written callee names in the current module, as
    the evaluator links it: the module's own function, a selectively imported
    one, or `Qualifier.name` through an import without a list. -}
resolveFunction :: LowerState -> [Text] -> Maybe Text
resolveFunction state segments = do
  let context = lowerContext state
      current = contextModule context
  scope <- Map.lookup current (contextModules context)
  target <- case segments of
    [name]
      | Set.member name (scopeFunctions scope) -> Just (current <> "." <> name)
      | otherwise -> (<> ("." <> name)) <$> Map.lookup name (scopeSelected scope)
    [qualifier, name] -> (<> ("." <> name)) <$> Map.lookup qualifier (scopeQualifiers scope)
    _ -> Nothing
  _ <- lookup target (contextTable context)
  pure target

{-| Whether a name is a module qualifier in the current module and not a local. -}
isModuleQualifier :: LowerState -> Text -> Bool
isModuleQualifier state name =
  lookupLocal state name == Nothing
    && maybe False (Map.member name . scopeQualifiers) (Map.lookup (contextModule context) (contextModules context))
 where
  context = lowerContext state

{-| Lower in another module: its facts and its names. -}
inModule :: Text -> LowerState -> LowerState
inModule name state = case Map.lookup name (contextModules context) of
  Just scope -> state{lowerContext = context{contextModule = name, contextTypes = scopeTypes scope}}
  Nothing -> state
 where
  context = lowerContext state

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
