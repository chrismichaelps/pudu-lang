{-| @Type.Ownership.Flow — the move state ownership checking carries through a body -}
module Pudu.Type.Ownership.Flow
  ( Walk
  , Facts (..)
  , Mode (..)
  , runWalk
  , lift
  , facts
  , typeAt
  , refuse
  , bindBinder
  , ownTemporary
  , withScope
  , withClosure
  , resolveBinder
  , movedAt
  , markMoved
  , reinitialize
  , stop
  , branches
  , loopWith
  , LoopShape (..)
  , breakTo
  , continueTo
  , withFreshFlow
  ) where

import Control.Monad (when)
import Data.IntMap.Strict (IntMap)
import qualified Data.IntMap.Strict as IntMap
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Source (Span)
import Pudu.Type.Drop (needsDrop)
import Pudu.Type.Env (Checker, report)
import Pudu.Type.Value (Type)

{-| What checking settled that the ownership walk reads: every expression's
    type, the receivers of declared methods with whether each is taken by
    value, and the prelude values a call treats as reads. -}
data Facts = Facts
  { factTypes :: !(Map Span Type)
  , factReceivers :: !(Map Span Bool)
  , factBuiltins :: !(Set Text)
  }

{-| Whether a position takes the value it is given or only reads it. -}
data Mode = Consume | Read
  deriving stock (Eq)

{-| A binder moved on every path reaching here, or on some of them. -}
data Moved = Definite !Span | Possible !Span

type Moves = IntMap Moved

data Scope = Scope
  { scopeNames :: !(Map Text Int)
  , scopeClosure :: !Bool
  }

{-| How a loop is left: by its condition failing, or only by `break`. -}
data LoopShape = Conditional | Unconditional
  deriving stock (Eq)

data LoopFrame = LoopFrame
  { frameLabel :: !(Maybe Text)
  , frameBreaks :: ![Moves]
  , frameContinues :: ![Moves]
  }

data WalkState = WalkState
  { walkFacts :: !Facts
  , walkScopes :: ![Scope]
  , walkNext :: !Int
  {-| Absent after an unconditional transfer: nothing after it runs. -}
  , walkFlow :: !(Maybe Moves)
  , walkLoops :: ![LoopFrame]
  , walkReporting :: !Bool
  , walkReported :: !(Set (Span, Text))
  , walkMoves :: !(Set Span)
  , walkOwned :: !(Set Span)
  }

newtype Walk a = Walk (WalkState -> Checker (a, WalkState))

instance Functor Walk where
  fmap transform (Walk action) = Walk $ \state -> do
    (value, next) <- action state
    pure (transform value, next)

instance Applicative Walk where
  pure value = Walk $ \state -> pure (value, state)
  Walk left <*> Walk right = Walk $ \state -> do
    (transform, afterLeft) <- left state
    (value, afterRight) <- right afterLeft
    pure (transform value, afterRight)

instance Monad Walk where
  Walk action >>= continue = Walk $ \state -> do
    (value, next) <- action state
    let Walk continued = continue value
    continued next

{-| Walk with the given facts; answers the spans of every use that moved and
    of every binder that owns a value needing drop. -}
runWalk :: Facts -> Walk () -> Checker (Set Span, Set Span)
runWalk known (Walk action) = do
  (_, final) <- action WalkState
    { walkFacts = known
    , walkScopes = []
    , walkNext = 0
    , walkFlow = Just IntMap.empty
    , walkLoops = []
    , walkReporting = True
    , walkReported = Set.empty
    , walkMoves = Set.empty
    , walkOwned = Set.empty
    }
  pure (walkMoves final, walkOwned final)

lift :: Checker a -> Walk a
lift action = Walk $ \state -> do
  value <- action
  pure (value, state)

gets :: (WalkState -> a) -> Walk a
gets field = Walk $ \state -> pure (field state, state)

modify :: (WalkState -> WalkState) -> Walk ()
modify change = Walk $ \state -> pure ((), change state)

facts :: Walk Facts
facts = gets walkFacts

typeAt :: Span -> Walk (Maybe Type)
typeAt at = Map.lookup at . factTypes <$> facts

{-| Report once per span and code, and only on the walk that reports: a loop
    body is walked twice and only the second walk speaks. -}
refuse :: Text -> Span -> Text -> Text -> Walk ()
refuse code at message help = do
  speaking <- gets walkReporting
  seen <- gets (Set.member (at, code) . walkReported)
  when (speaking && not seen) $ do
    modify (\state -> state{walkReported = Set.insert (at, code) (walkReported state)})
    lift (report code at message (Just help))

{-| Introduce a binder; one whose settled type needs drop owns its value. -}
bindBinder :: Located Text -> Walk ()
bindBinder (Located at name) = do
  held <- typeAt at
  owning <- maybe (pure False) (lift . needsDrop) held
  when owning (modify (\state -> state{walkOwned = Set.insert at (walkOwned state)}))
  introduce name

{-| A statement's value that needs drop and that nothing takes is dropped
    where the statement ends. -}
ownTemporary :: Span -> Walk ()
ownTemporary at = modify (\state -> state{walkOwned = Set.insert at (walkOwned state)})

introduce :: Text -> Walk ()
introduce name = modify $ \state -> case walkScopes state of
  scope : rest ->
    state
      { walkScopes = scope{scopeNames = Map.insert name (walkNext state) (scopeNames scope)} : rest
      , walkNext = walkNext state + 1
      }
  [] -> state

withScope :: Walk a -> Walk a
withScope = scoped False

{-| A closure body: binders outside it are captures. -}
withClosure :: Walk a -> Walk a
withClosure = scoped True

scoped :: Bool -> Walk a -> Walk a
scoped closure body = do
  modify (\state -> state{walkScopes = Scope Map.empty closure : walkScopes state})
  value <- body
  modify (\state -> state{walkScopes = drop 1 (walkScopes state)})
  pure value

{-| The binder a bare name reaches, and whether reaching it crosses into an
    enclosing closure's surroundings. -}
resolveBinder :: Text -> Walk (Maybe (Int, Bool))
resolveBinder name = search False <$> gets walkScopes
 where
  search crossed scopes = case scopes of
    [] -> Nothing
    scope : rest -> case Map.lookup name (scopeNames scope) of
      Just binder -> Just (binder, crossed)
      Nothing -> search (crossed || scopeClosure scope) rest

{-| Where the binder was moved, if it was on any path reaching here. -}
movedAt :: Int -> Walk (Maybe (Bool, Span))
movedAt binder = do
  flow <- gets walkFlow
  pure $ case flow >>= IntMap.lookup binder of
    Just (Definite at) -> Just (True, at)
    Just (Possible at) -> Just (False, at)
    Nothing -> Nothing

markMoved :: Int -> Span -> Walk ()
markMoved binder at = modify $ \state -> case walkFlow state of
  Just flow ->
    state
      { walkFlow = Just (IntMap.insert binder (Definite at) flow)
      , walkMoves = Set.insert at (walkMoves state)
      }
  Nothing -> state

reinitialize :: Int -> Walk ()
reinitialize binder = modify (\state -> state{walkFlow = IntMap.delete binder <$> walkFlow state})

{-| Nothing after an unconditional transfer runs. -}
stop :: Walk ()
stop = modify (\state -> state{walkFlow = Nothing})

{-| Run alternatives from the same state and continue from their join. -}
branches :: [Walk ()] -> Walk ()
branches alternatives = do
  start <- gets walkFlow
  ends <- mapM (\alternative -> setFlow start >> alternative >> gets walkFlow) alternatives
  setFlow (joinAll ends)

setFlow :: Maybe Moves -> Walk ()
setFlow flow = modify (\state -> state{walkFlow = flow})

joinAll :: [Maybe Moves] -> Maybe Moves
joinAll = foldr joinFlow Nothing

joinFlow :: Maybe Moves -> Maybe Moves -> Maybe Moves
joinFlow left right = case (left, right) of
  (Nothing, other) -> other
  (other, Nothing) -> other
  (Just a, Just b) -> Just (IntMap.mergeWithKey both (IntMap.map possible) (IntMap.map possible) a b)
 where
  both _ (Definite at) (Definite _) = Just (Definite at)
  both _ first _ = Just (possible first)
  possible moved = case moved of
    Definite at -> Possible at
    Possible at -> Possible at

{-| Walk a loop: once silently to learn what a turn moves, then again from
    the join of entry and every way back to the head, reporting. The loop is
    left with the head state when its condition can fail, and with each
    `break`'s state. -}
loopWith :: Maybe Text -> LoopShape -> Walk () -> Walk ()
loopWith label shape turn = do
  entry <- gets walkFlow
  speaking <- gets walkReporting
  modify (\state -> state{walkReporting = False})
  (afterFirst, firstFrame) <- oneTurn entry
  modify (\state -> state{walkReporting = speaking})
  let head' = joinAll (entry : afterFirst : map Just (frameContinues firstFrame))
  (afterSecond, frame) <- oneTurn head'
  let headAgain = joinAll (head' : afterSecond : map Just (frameContinues frame))
      leaving = frameBreaks frame
  setFlow (joinAll ((if shape == Conditional then [headAgain] else []) <> map Just leaving))
 where
  oneTurn start = do
    setFlow start
    modify (\state -> state{walkLoops = LoopFrame label [] [] : walkLoops state})
    turn
    end <- gets walkFlow
    frames <- gets walkLoops
    modify (\state -> state{walkLoops = drop 1 (walkLoops state)})
    pure (end, case frames of
      frame : _ -> frame
      [] -> LoopFrame label [] [])

breakTo :: Maybe Text -> Walk ()
breakTo label = transfer label (\flow frame -> frame{frameBreaks = flow : frameBreaks frame})

continueTo :: Maybe Text -> Walk ()
continueTo label = transfer label (\flow frame -> frame{frameContinues = flow : frameContinues frame})

transfer :: Maybe Text -> (Moves -> LoopFrame -> LoopFrame) -> Walk ()
transfer label record = do
  flow <- gets walkFlow
  case flow of
    Nothing -> pure ()
    Just moves -> modify (\state -> state{walkLoops = recordIn moves (walkLoops state)})
  stop
 where
  recordIn moves frames = case frames of
    [] -> []
    frame : rest
      | maybe True (\wanted -> frameLabel frame == Just wanted) label -> record moves frame : rest
      | otherwise -> frame : recordIn moves rest

{-| A closure or nested function body runs apart from the surrounding flow:
    its moves are its own and its transfers never reach an outer loop. -}
withFreshFlow :: Walk () -> Walk ()
withFreshFlow body = do
  outer <- gets walkFlow
  loops <- gets walkLoops
  modify (\state -> state{walkFlow = Just IntMap.empty, walkLoops = []})
  body
  modify (\state -> state{walkFlow = outer, walkLoops = loops})
