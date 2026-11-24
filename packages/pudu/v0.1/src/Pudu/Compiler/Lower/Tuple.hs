{-| @Pudu.Compiler.Lower.Tuple — tuple literals and tuple and record patterns in `let`. -}
module Pudu.Compiler.Lower.Tuple (lowerTuple, lowerTuplePattern) where

import Data.List (mapAccumL, transpose)
import qualified Data.Set as Set
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.Dynamic (joinRuntimeArms, mapRuntimeChoice, normalizeAggregateValue, projectRuntimeValue, runtimeCarriers, storageCarrier)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, refused)
import Pudu.Compiler.Lower.Types (nativeValueType, ownerKeyOf, recordFields, sumVariants, typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax
  ( Expression, FieldPattern (..), Located (..), Pattern (..), TypeSyntax )
import Pudu.Source (Span)
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text

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

{-| Retain the subject while testing the whole pattern. Bindings are
    published together after the selected shape has matched. -}
lowerTuplePattern :: LowerExpression -> LowerState -> Span -> Located Pattern -> Maybe (Located TypeSyntax)
  -> Located Expression -> (LowerState, Maybe [CoreStatement])
lowerTuplePattern lower state at pattern _ subject = case lower state subject of
  (after, Nothing) -> refused after
  (after, Just (value, kind))
    | expressionIsPrintValued value -> halt at "binding a Result[(), Str] value" after
    | kind == CoreNeverType -> (after, Just [evaluate value])
    | otherwise ->
        let types = contextTypes (lowerContext after)
            (normalized, held) = normalizeAggregateValue types (typeForSpan types (locatedSpan subject)) after value
            (withRoot, rootLocal) = bindLocal normalized "" (coreExpressionType held)
            root = readLocal rootLocal
            (ready, packed) = bindPattern root withRoot root pattern finish
            (final, declarations) = publish types ready packed
         in (final, Just (declare rootLocal held : declarations))
 where
  patternAt = locatedSpan pattern
  declare local value = CoreStatement at (CoreDeclare local value)
  evaluate value = CoreStatement at (CoreEvaluate value)
  readLocal local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
  finish current [] = (current, CoreExpression at CoreUnitType (CoreBlockValue (CoreBlock [] Nothing)))
  finish current values = (current, CoreExpression at (CoreTupleType (map coreExpressionType values)) (CoreTuple values))

  failPattern root =
    let text = CoreExpression patternAt CoreTextType
        append left right = text (CoreBinary CoreAdd left right)
        kind = text (CoreRuntimeKind root)
        message = append (text (CoreTextLiteral "this pattern does not match the "))
          (append kind (text (CoreTextLiteral " it was given")))
     in CoreExpression patternAt CoreNeverType
          (CoreFailText "E7013" (Just "check the number of elements the pattern names against the value") message Nothing)

  bindPattern root current value written@(Located spanValue shape) next = case shape of
    WildcardPattern -> next current []
    BindingPattern _ -> next current [value]
    _ | Just (ready, Just (selected, _)) <- mapRuntimeChoice current spanValue CoreNeverType value
          (\prior held -> fmap Just (bindPattern root prior held written next)) -> (ready, selected)
    TuplePattern members
      | CoreTupleType kinds <- coreExpressionType value, length kinds == length members ->
          let fields = [CoreExpression spanValue kind (CoreTupleIndex position value)
                | (position, kind) <- zip [0 ..] kinds]
           in walk root current (zip fields members) next
    RecordPattern path fields _
      | CoreRecordType owner _ <- coreExpressionType value
      , matchesOwner path owner
      , Just declared <- recordFields (contextTypes (lowerContext current)) (coreExpressionType value) ->
          let projected = [(name, CoreExpression spanValue kind (CoreField name value)) | (name, kind) <- declared]
           in recordBindings root current projected fields next
      | Just variants <- sumVariants (contextTypes (lowerContext current)) (coreExpressionType value) ->
          let arm prior variant
                | coreVariantRecord variant, matchesVariant path (ownerKeyOf (coreExpressionType value)) (coreVariantName variant) =
                    let declared = coreVariantFields variant
                        hold entered (_, kind) = bindLocal entered "" kind
                        (bound, locals) = mapAccumL hold prior declared
                        projected = zip (map fst declared) (map readLocal locals)
                        (finished, body) = recordBindings root bound projected fields next
                     in (finished, CoreArm spanValue (CoreVariantPattern (coreVariantName variant) (map CoreBindPattern locals)) Nothing body)
                | otherwise =
                    (prior, CoreArm spanValue (CoreVariantPattern (coreVariantName variant) (map (const CoreWildcardPattern) (coreVariantFields variant))) Nothing (failPattern root))
              (ready, arms) = mapAccumL arm current variants
           in (ready, joinRuntimeArms spanValue CoreNeverType value arms)
    _ -> (current, failPattern root)

  recordBindings root current declared fields next =
    case traverse pick fields of
      Nothing -> (current, failPattern root)
      Just pairs -> walk root current pairs next
   where
    pick (Located _ (FieldPattern name inner)) = do
      value <- lookup (locatedValue name) declared
      pure (value, fieldPattern name inner)

  walk _ current [] next = next current []
  walk root current ((value, written) : rest) next =
    bindPattern root current value written (\ready first ->
      walk root ready rest (\final remaining -> next final (first <> remaining)))

  fieldPattern name = maybe (Located (locatedSpan name) (BindingPattern name)) id
  names (Located _ shape) = case shape of
    BindingPattern name -> [name]
    TuplePattern members -> concatMap names members
    RecordPattern _ fields _ -> concat [names (fieldPattern name inner) | Located _ (FieldPattern name inner) <- fields]
    _ -> []
  matchesOwner Nothing _ = True
  matchesOwner (Just (ModuleName parts)) owner = case parts of
    "::sum::" :| _ -> False
    symbol :| [] | Text.isInfixOf "." symbol -> symbol == owner
    _ -> NonEmpty.last parts == displayName owner
  matchesVariant (Just (ModuleName ("::sum::" :| [wantedOwner, wantedName]))) owner name =
    Just wantedOwner == owner && wantedName == name
  matchesVariant path _ name = matchesOwner path name

  publish types current packed = case coreExpressionShape packed of
    CoreTuple values -> publishLocals current (zip (names pattern) values)
    _ | coreExpressionType packed == CoreNeverType || null (names pattern) -> (current, [evaluate packed])
    _ ->
      let vectors = [slots | CoreTupleType slots <- Set.toList (runtimeCarriers (coreExpressionType packed))]
          layout kinds = case kinds of
            first : _ -> storageCarrier types first kinds
            [] -> CoreUnitType
          members = map layout (transpose vectors)
          carrier = CoreTupleType members
          (projected, carried) = projectRuntimeValue types current carrier packed
          (ready, saved) = bindLocal projected "" carrier
          values = [CoreExpression at kind (CoreTupleIndex position (readLocal saved))
            | (position, kind) <- zip [0 ..] members]
          (final, statements) = publishLocals ready (zip (names pattern) values)
       in (final, declare saved carried : statements)
  publishLocals = mapAccumL (\prior (name, value) ->
    let (next, local) = bindLocal prior (locatedValue name) (coreExpressionType value)
     in (next, declare local value))
