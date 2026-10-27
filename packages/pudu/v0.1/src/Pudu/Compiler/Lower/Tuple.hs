{-| @Pudu.Compiler.Lower.Tuple — tuple literals, literal positions, and
    tuple and record patterns in `let`. -}
module Pudu.Compiler.Lower.Tuple (lowerTuple, lowerTupleIndex, lowerTuplePattern) where

import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, refused)
import Pudu.Compiler.Lower.Types (nativeValueType, typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax
  ( Expression (..), FieldPattern (..), Literal (..), Located (..), Pattern (..), TypeSyntax )
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

{-| Members run left to right. Once one never finishes, the tuple is never
    built, but the members before it have still run. -}
lowerTuple :: LowerExpression -> LowerState -> Span -> [Located Expression] -> (LowerState, Maybe (CoreExpression, CoreType))
lowerTuple lower state at = go state []
 where
  go current done [] =
    let members = reverse done
        kinds = map coreExpressionType members
     in if CoreNeverType `elem` kinds
          then built current (effects members) CoreNeverType
          else let kind = CoreTupleType kinds
                in if nativeValueType kind
                     then built current (CoreTuple members) kind
                     else halt at ("tuples of type " <> coreTypeName kind) current
  go current done (member : rest) = case lower current member of
    (next, Nothing) -> refused next
    (next, Just (core, _))
      | expressionIsPrintValued core -> halt (locatedSpan member) "a Result[(), Str] tuple member" next
      | coreExpressionType core == CoreNeverType -> go next (core : done) []
      | otherwise -> go next (core : done) rest
  built current shape kind = (current, Just (CoreExpression at kind shape, kind))
  effects members = CoreBlockValue (CoreBlock
    [CoreStatement (coreExpressionSpan member) (CoreEvaluate member) | member <- members] Nothing)

{-| The checker only accepts a literal, in-range position on a tuple. -}
lowerTupleIndex :: LowerExpression -> LowerState -> Span -> Located Expression -> Located Expression
  -> (LowerState, Maybe (CoreExpression, CoreType))
lowerTupleIndex lower state at receiver key = case lower state receiver of
  (after, Nothing) -> refused after
  (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
  (after, Just (core, CoreTupleType members)) -> case locatedValue key of
    LiteralExpression (ResolvedInteger _ position)
      | position >= 0, position < fromIntegral (length members) ->
          let kind = members !! fromInteger position
           in (after, Just (CoreExpression at kind (CoreTupleIndex (fromInteger position) core), kind))
    _ -> halt (locatedSpan key) "a tuple position that is not a literal in range" after
  (after, Just (_, kind)) -> halt at ("indexing a " <> coreTypeName kind <> " value") after

{-| `let (a, (b, _)) = subject`: the subject runs once into a hidden local,
    then each name reads its position. A tuple pattern of names and
    wildcards cannot fail on a tuple, so there is no refusal path to model. -}
lowerTuplePattern :: LowerExpression -> LowerState -> Span -> Located Pattern -> Maybe (Located TypeSyntax)
  -> Located Expression -> (LowerState, Maybe [CoreStatement])
lowerTuplePattern lower state at pattern annotation subject = case lower state subject of
  (after, Nothing) -> refused after
  (after, Just (core, kind))
    | expressionIsPrintValued core -> halt at "binding a Result[(), Str] value" after
    | kind == CoreNeverType -> halt at "a pattern binding whose subject never finishes" after
    | Just _ <- annotation
    , typeForSpan (contextTypes (lowerContext after)) (locatedSpan subject) /= Just kind ->
        halt at "a binding without matching solved native type facts" after
    | otherwise ->
        let (withHidden, hidden) = bindLocal after "$pattern" kind
            root = CoreExpression (locatedSpan subject) kind (CoreReadLocal hidden)
         in case bindings withHidden root pattern of
              (final, Just declared) ->
                (final, Just (CoreStatement at (CoreDeclare hidden core) : declared))
              (final, Nothing) -> (final, Nothing)
 where
  bindings current source (Located patternSpan shape) = case (shape, coreExpressionType source) of
    (WildcardPattern, _) -> (current, Just [])
    (BindingPattern (Located _ name), kind) ->
      let (next, local) = bindLocal current name kind
       in (next, Just [CoreStatement patternSpan (CoreDeclare local source)])
    (TuplePattern members, CoreTupleType kinds)
      | length members == length kinds -> foldMembers current [] (zip3 [0 ..] kinds members)
      where
        foldMembers state' collected [] = (state', Just (concat (reverse collected)))
        foldMembers state' collected ((position, kind, member) : rest) =
          let projected = CoreExpression (locatedSpan member) kind (CoreTupleIndex position source)
           in case bindings state' projected member of
                (next, Just declared) -> foldMembers next (declared : collected) rest
                (next, Nothing) -> (next, Nothing)
    (RecordPattern _ fields _, CoreRecordType _ declared) -> foldFields current [] fields
      where
        -- `{x}` binds x; `{x: inner}` matches inner against the field.
        foldFields state' collected [] = (state', Just (concat (reverse collected)))
        foldFields state' collected (Located fieldSpan (FieldPattern (Located nameSpan name) inner) : rest) =
          case lookup name declared of
            Nothing -> halt fieldSpan ("the field '" <> name <> "'") state'
            Just kind ->
              let projected = CoreExpression fieldSpan kind (CoreField name source)
                  pattern' = maybe (Located nameSpan (BindingPattern (Located nameSpan name))) id inner
               in case bindings state' projected pattern' of
                    (next, Just declared') -> foldFields next (declared' : collected) rest
                    (next, Nothing) -> (next, Nothing)
    _ -> halt patternSpan "this pattern in a let binding" current
