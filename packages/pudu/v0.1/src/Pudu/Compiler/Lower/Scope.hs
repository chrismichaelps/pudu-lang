{-| @Compiler.Lower.Scope — structured task scopes. A task is adopted by the
    innermost open scope when it is made and let go when it is awaited; the
    children left are joined, in the order they were made, on every way out
    of the scope: its end, a `return`, a loop transfer, or a failure that
    leaves the function. -}
module Pudu.Compiler.Lower.Scope (released, lowerScope, leaving, leavingLoop) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Control (popLoop, pushLoop)
import Pudu.Compiler.Lower.State (LoopFrame (..), LowerState (..), bindLocal)
import Pudu.Compiler.Lower.Types (nativeValueType)
import Pudu.Core
import Pudu.Frontend.Syntax (Block, Located (..))
import Pudu.Source (Span)

type LowerBlock = LowerState -> Located Block -> (LowerState, CoreBlock, CoreType)

joinerType :: CoreType
joinerType = CoreFunctionType [] CoreBoolType

host :: Span -> CoreType -> Text -> [CoreExpression] -> CoreExpression
host at kind name operands = CoreExpression at kind (CoreKernel (KernelHost name) [] operands)

effect :: Span -> Text -> [CoreExpression] -> CoreStatement
effect at name operands = CoreStatement at (CoreEvaluate (host at CoreBoolType name operands))

reading :: Span -> CoreLocal -> CoreExpression
reading at local = CoreExpression at (coreLocalType local) (CoreReadLocal local)

{-| A task about to be awaited: the innermost scope lets it go, then it runs. -}
released :: LowerState -> Span -> CoreExpression -> CoreType -> (LowerState, CoreExpression)
released state at task answered =
  let (bound, held) = bindLocal state "" (coreExpressionType task)
      ran = CoreExpression at answered (CoreCallValue (reading at held) [])
   in (bound, CoreExpression at answered (CoreBlockValue (CoreBlock
        [CoreStatement at (CoreDeclare held task), effect at "scope_release" [reading at held]] (Just ran))))

{-| `scope { body }`: the body runs with the scope open, then its children
    are joined and the body's value is the scope's. -}
lowerScope :: LowerBlock -> LowerState -> Span -> Located Block -> (LowerState, Maybe (CoreExpression, CoreType))
lowerScope lowerBlock state at body =
  let opened = state{lowerOpenScopes = length (lowerLoops state) : lowerOpenScopes state}
      (inside, coreBlock, kind) = lowerBlock opened body
      closed = inside{lowerOpenScopes = lowerOpenScopes state}
      ran = CoreExpression at kind (CoreBlockValue coreBlock)
      open = effect at "scope_open" []
   in case kind of
        CoreNeverType -> (closed, Just (CoreExpression at kind (CoreBlockValue (CoreBlock [open, CoreStatement at (CoreEvaluate ran)] Nothing)), kind))
        CoreUnitType ->
          let (joined, joins) = joinThen closed at (lowerOpenScopes state)
           in (joined, Just (CoreExpression at kind (CoreBlockValue (CoreBlock ([open, CoreStatement at (CoreEvaluate ran)] <> joins) Nothing)), kind))
        _ ->
          let (withValue, value) = bindLocal closed "" kind
              (joined, joins) = joinThen withValue at (lowerOpenScopes state)
           in (joined, Just (CoreExpression at kind (CoreBlockValue (CoreBlock ([open, CoreStatement at (CoreDeclare value ran)] <> joins) (Just (reading at value)))), kind))

{-| Join the scope just closed. A child that failed ends the joining: the
    scopes still open around it are joined in turn, and the function answers
    the failure. -}
joinThen :: LowerState -> Span -> [Int] -> (LowerState, [CoreStatement])
joinThen state at outer =
  let (pushed, identity) = pushLoop Nothing state
      (withJoiner, joiner) = bindLocal pushed "" joinerType
      (afterOuter, outward) = joinAll (popLoop withJoiner) at outer
      (final, answer) = failing afterOuter at
      present = CoreExpression at CoreBoolType (CoreKernel KernelPresent [] [reading at joiner])
      stop = CoreBlock [CoreStatement at (CoreBreak identity Nothing)] Nothing
      failed = CoreBlock ([effect at "scope_abandon" []] <> outward <> answer) Nothing
      turn = CoreBlock
        [ CoreStatement at (CoreDeclare joiner (host at joinerType "scope_next" []))
        , CoreStatement at (CoreIf (CoreExpression at CoreBoolType (CoreNot present)) stop Nothing)
        , CoreStatement at (CoreIf (CoreExpression at CoreBoolType (CoreCallValue (reading at joiner) [])) failed Nothing) ] Nothing
   in (final, [effect at "scope_close" [], CoreStatement at (CoreEvaluate (CoreExpression at CoreUnitType (CoreLoopValue identity turn)))])

{-| Join each of these open scopes, innermost first. -}
joinAll :: LowerState -> Span -> [Int] -> (LowerState, [CoreStatement])
joinAll state _ [] = (state, [])
joinAll state at (_ : outer) =
  let (joined, statements) = joinThen state at outer
      (rest, more) = joinAll joined at outer
   in (rest, statements <> more)

{-| What the function answers when a joined task failed: the failure, where
    the function answers a Result of that failure; otherwise the program
    stops, since nothing can carry it. -}
failing :: LowerState -> Span -> (LowerState, [CoreStatement])
failing state at = case maybe (lowerDeclaredResult state) Just (lowerFunctionResult state) of
  Just result@(CoreSumType "Result" [_, failure]) | nativeValueType failure ->
    let carrier = CoreTupleType [failure]
        (bound, kept) = bindLocal state "" carrier
        present = CoreExpression at CoreBoolType (CoreKernel KernelPresent [] [reading at kept])
        answer = CoreExpression at result (CoreConstruct "Err" [("0", CoreExpression at failure (CoreTupleIndex 0 (reading at kept)))])
     in (bound, [ CoreStatement at (CoreDeclare kept (host at carrier "scope_stashed" []))
                , CoreStatement at (CoreIf (CoreExpression at CoreBoolType (CoreNot present)) (CoreBlock [stopped] Nothing) Nothing)
                , CoreStatement at (CoreReturn (Just answer)) ])
  _ -> (state, [stopped])
 where
  stopped = CoreStatement at (CoreEvaluate (CoreExpression at CoreNeverType (CoreFailText "E7001" Nothing
    (CoreExpression at CoreTextType (CoreTextLiteral "a task joined by this scope failed where its function answers no such failure")) Nothing)))

{-| The joins a `return` owes: every scope open in this function. -}
leaving :: LowerState -> Span -> (LowerState, [CoreStatement])
leaving state at = joinAll state at (lowerOpenScopes state)

{-| The joins a transfer to this loop owes: the scopes opened inside it. -}
leavingLoop :: LowerState -> Span -> CoreLoopId -> (LowerState, [CoreStatement])
leavingLoop state at identity =
  let frames = lowerLoops state
      depth = length (dropWhile ((/= identity) . loopIdentity) frames)
      inside = takeWhile (>= depth) (lowerOpenScopes state)
      outer = drop (length inside) (lowerOpenScopes state)
      go current [] = (current, [])
      go current (_ : rest) =
        let (joined, statements) = joinThen current at (rest <> outer)
            (final, more) = go joined rest
         in (final, statements <> more)
   in go state inside
