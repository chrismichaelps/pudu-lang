{-| @Compiler.Lower.Drop — drops owned values where native scopes end

    A local that owns a value needing drop is dropped where its scope ends,
    on every way out, unless a move left it empty. Dropping calls one glue
    function per type: the type's own `drop` with the value whole, then each
    part that needs drop, in declaration order. -}
module Pudu.Compiler.Lower.Drop
  ( ownedAt
  , adoptLocal
  , adoptLocals
  , adoptOwned
  , ownedLocals
  , dropValue
  , droppingBlock
  , closingScope
  , droppingAll
  , droppingLoop
  , needsDropType
  ) where

import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Char (isAlphaNum)
import Pudu.Core
import Pudu.Compiler.Lower.Method (invokeLent, unselected)
import Pudu.Compiler.Lower.State
  ( LowerContext (..), LowerState (..), LoopFrame (..), ModuleScope (..), bindLocal, startFunction )
import Pudu.Compiler.Lower.Types (LowerTypes, ownerKeyOf, recordFields, sumVariants)
import Pudu.Source (Span)

{-| Whether checking marked the binder or statement at this span as owning a
    value that needs drop. Spans restart in every module, so only the module
    whose function is being lowered can answer. -}
ownedAt :: LowerState -> Span -> Bool
ownedAt state at = case Map.lookup (contextModule context) (contextModules context) of
  Just scope -> Set.member at (scopeOwned scope)
  Nothing -> False
 where
  context = lowerContext state

{-| The local just bound at this span owns its value when checking said so. -}
adoptLocal :: Span -> CoreLocal -> LowerState -> LowerState
adoptLocal at local state
  | ownedAt state at = adoptOwned at local state
  | otherwise = state

{-| The ids of the bound locals whose binders checking marked as owning. -}
ownedLocals :: LowerState -> [(Span, CoreLocal)] -> Set.Set Int
ownedLocals state bound = Set.fromList [coreLocalId local | (at, local) <- bound, ownedAt state at]

{-| The local owns its value from here on, whatever its binder: a task's copy
    of a parameter its async function handed over is one. It is dropped where
    its scope ends unless a move left it empty. -}
adoptOwned :: Span -> CoreLocal -> LowerState -> LowerState
adoptOwned at local state
  | (glued, Just key) <- glueFor state at (coreLocalType local) =
      let context = lowerContext glued
          held = (coreLocalId local, key)
       in glued
            { lowerOwned = Set.insert (coreLocalId local) (lowerOwned glued)
            , lowerContext = context{contextOwnedLocals =
                Map.insertWith (\new old -> old <> new) (lowerCurrentKey glued) [held] (contextOwnedLocals context)}
            }
  | otherwise = state

adoptLocals :: [(Span, CoreLocal)] -> LowerState -> LowerState
adoptLocals bound state = foldl' (\current (at, local) -> adoptLocal at local current) state bound

{-| Drop what the innermost scope owns. -}
droppingBlock :: LowerState -> Span -> (LowerState, [CoreStatement])
droppingBlock state at = dropFrames at (take 1 (lowerScopes state)) state

{-| End the innermost scope of a finished block: its result is kept, what
    the scope owns is dropped, and the kept result is the block's. A result
    that never arrives was left through a transfer that dropped already. -}
closingScope :: Span -> LowerState -> CoreBlock -> (LowerState, CoreBlock)
closingScope at state block
  | not owning = (state, block)
  | otherwise = case coreBlockResult block of
      Just value | coreExpressionType value == CoreNeverType -> (state, block)
      Just value ->
        let (bound, kept) = bindLocal state "" (coreExpressionType value)
            (dropped, drops) = droppingBlock bound at
         in ( dropped
            , CoreBlock (coreBlockStatements block <> [CoreStatement at (CoreDeclare kept value)] <> drops)
                (Just (CoreExpression at (coreExpressionType value) (CoreReadLocal kept))) )
      Nothing ->
        let (dropped, drops) = droppingBlock state at
         in (dropped, CoreBlock (coreBlockStatements block <> drops) Nothing)
 where
  owning = any (\(_, local) -> Set.member (coreLocalId local) (lowerOwned state)) (concat (take 1 (lowerScopes state)))

{-| Drop what every scope of the function owns, its parameters included. -}
droppingAll :: LowerState -> Span -> (LowerState, [CoreStatement])
droppingAll state at = dropFrames at (lowerScopes state) state

{-| Drop what the scopes opened inside a loop own, for a transfer to it. -}
droppingLoop :: LowerState -> Span -> CoreLoopId -> (LowerState, [CoreStatement])
droppingLoop state at identity = case [frame | frame <- lowerLoops state, loopIdentity frame == identity] of
  frame : _ -> dropFrames at (take (length (lowerScopes state) - loopScopeDepth frame) (lowerScopes state)) state
  [] -> (state, [])

{-| Newest first within a scope and innermost scope first, which is reverse
    declaration order. Each local is taken, so a later way out sees it empty. -}
dropFrames :: Span -> [[(Text, CoreLocal)]] -> LowerState -> (LowerState, [CoreStatement])
dropFrames at frames state = foldl' step (state, []) owned
 where
  owned = [local | frame <- frames, (_, local) <- frame, Set.member (coreLocalId local) (lowerOwned state)]
  step (current, done) local =
    case dropValue current at (CoreExpression at (coreLocalType local) (CoreTakeLocal local)) of
      (next, Just statement) -> (next, done <> [statement])
      (next, Nothing) -> (next, done)

{-| A statement dropping this value, when its type needs drop. -}
dropValue :: LowerState -> Span -> CoreExpression -> (LowerState, Maybe CoreStatement)
dropValue state at value = case glueFor state at (coreExpressionType value) of
  (next, Just key) ->
    (next, Just (CoreStatement at (CoreEvaluate (CoreExpression at CoreUnitType (CoreCall key [value])))))
  (next, Nothing) -> (next, Nothing)

{-| A type needs drop when it has its own `drop` or holds a part that does. -}
needsDropType :: LowerState -> CoreType -> Bool
needsDropType state = decide Set.empty
 where
  context = lowerContext state
  types = contextTypes context
  decide visiting kind
    | Set.member kind visiting = False
    | ownDrop context kind = True
    | otherwise = any (decide (Set.insert kind visiting)) (parts types kind)

ownDrop :: LowerContext -> CoreType -> Bool
ownDrop context kind = case ownerKeyOf kind of
  Just owner -> Map.member (dropTraitName, owner, "drop") (contextTraitMethods context)
  Nothing -> False

dropTraitName :: Text
dropTraitName = "Drop"

parts :: LowerTypes -> CoreType -> [CoreType]
parts types kind = case kind of
  CoreTupleType members -> members
  CoreRecordType _ _ -> maybe [] (map snd) (recordFields types kind)
  CoreSumType _ _ -> concatMap (map snd . coreVariantFields) (fromMaybe [] (sumVariants types kind))
  _ -> []

{-| The glue function for a type that needs drop, made once. Its key is
    marked made before its body is built, so a type that holds itself calls
    the glue being built. -}
glueFor :: LowerState -> Span -> CoreType -> (LowerState, Maybe Text)
glueFor state at kind
  | not (needsDropType state kind) = (state, Nothing)
  | Set.member key (contextDrops (lowerContext state)) = (state, Just key)
  | otherwise =
      let marked = state{lowerContext = (lowerContext state){contextDrops = Set.insert key (contextDrops (lowerContext state))}}
          self = CoreLocal 0 "self" kind
          parameter = CoreParameter self at
          entered = (startFunction marked [parameter] (Just CoreUnitType)){lowerCurrentKey = key}
          (built, statements) = glueBody entered at self
          present = CoreExpression at CoreBoolType (CoreKernel KernelPresent [] [reading self])
          body = CoreBlock [CoreStatement at (CoreIf present (CoreBlock statements Nothing) Nothing)] Nothing
          function = CoreFunction key [parameter] CoreUnitType body
          context = lowerContext built
       in (state{lowerContext = context{contextFunctions = function : contextFunctions context}}, Just key)
 where
  key = "::drop::" <> Text.map (\character -> if isAlphaNum character then character else '_') (Text.pack (show kind))
  reading local = CoreExpression at (coreLocalType local) (CoreReadLocal local)

{-| The type's own `drop` with the value whole, then its parts in order. -}
glueBody :: LowerState -> Span -> CoreLocal -> (LowerState, [CoreStatement])
glueBody state at self = (afterParts, own <> rest)
 where
  kind = coreLocalType self
  context = lowerContext state
  types = contextTypes context
  reading local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
  (afterOwn, own) = case ownerKeyOf kind >>= \owner -> Map.lookup (dropTraitName, owner, "drop") (contextTraitMethods context) of
    Just instanceKey -> case invokeLent [0] state at instanceKey Nothing unselected [reading self] of
      (called, Just (call, answered)) ->
        let (bound, answer) = bindLocal called "" answered
            final = CoreExpression at kind (CoreTupleIndex 1 (reading answer))
         in (bound, [CoreStatement at (CoreDeclare answer call), CoreStatement at (CoreAssign self final)])
      (called, Nothing) -> (called, [])
    Nothing -> (state, [])
  (afterParts, rest) = case kind of
    CoreTupleType members ->
      dropAll afterOwn [CoreExpression at member (CoreTupleIndex index (reading self)) | (index, member) <- zip [0 ..] members]
    CoreRecordType _ _ ->
      dropAll afterOwn [CoreExpression at fieldType (CoreField name (reading self)) | (name, fieldType) <- fromMaybe [] (recordFields types kind)]
    CoreSumType _ _ -> case sumVariants types kind of
      Just variants | any (any (needsDropType afterOwn . snd) . coreVariantFields) variants ->
        let (armed, arms) = foldl' arm (afterOwn, []) variants
         in (armed, [CoreStatement at (CoreEvaluate (CoreExpression at CoreUnitType (CoreMatch (reading self) arms)))])
      _ -> (afterOwn, [])
    _ -> (afterOwn, [])
  dropAll current values = foldl' (\(now, done) value -> case dropValue now at value of
    (next, Just statement) -> (next, done <> [statement])
    (next, Nothing) -> (next, done)) (current, []) values
  arm (current, done) variant =
    let (bound, locals) = foldl' (\(now, held) (_, fieldType) ->
          let (next, local) = bindLocal now "" fieldType in (next, held <> [local])) (current, []) (coreVariantFields variant)
        (dropped, statements) = dropAll bound (map reading locals)
        body = CoreExpression at CoreUnitType (CoreBlockValue (CoreBlock statements Nothing))
        pattern = CoreVariantPattern (coreVariantName variant) (map CoreBindPattern locals)
     in (dropped, done <> [CoreArm at pattern Nothing body])
