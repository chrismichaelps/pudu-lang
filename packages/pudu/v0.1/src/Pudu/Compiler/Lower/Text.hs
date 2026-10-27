{-| @Pudu.Compiler.Lower.Text — built-in Str methods on a lowered receiver. -}
module Pudu.Compiler.Lower.Text (lowerTextMethod) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (LowerState, halt, intType, refused)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

{-| The receiver's type decides whether this is a Str method at all. Str
    answers its own methods before any impl, so there is no lookup to make. -}
lowerTextMethod :: LowerExpression -> LowerState -> Span -> Located Expression -> Text -> [Located Expression]
  -> (LowerState, Maybe (CoreExpression, CoreType))
lowerTextMethod lower state at receiver member arguments = case lower state receiver of
  (after, Nothing) -> refused after
  (after, Just (coreReceiver, CoreTextType)) -> case lookup member methods of
    Nothing -> halt at ("the Str method '" <> member <> "'") after
    Just (name, parameters, result) -> collect after [] (zip parameters arguments)
      where
        collect current done []
          | length arguments /= length parameters =
              halt at ("a call to " <> member <> " with this many arguments") current
          | any ((== CoreNeverType) . coreExpressionType) (reverse done <> [coreReceiver]) =
              let operands = reverse done <> [coreReceiver]
               in built current (CoreBlockValue (CoreBlock
                    [CoreStatement (coreExpressionSpan operand) (CoreEvaluate operand) | operand <- operands] Nothing))
                    CoreNeverType
          | otherwise = built current (CoreTextMethod name coreReceiver (reverse done)) result
        collect current done ((expected, argument) : rest) = case lower current argument of
          (next, Nothing) -> refused next
          (next, Just (core, kind))
            | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] method argument" next
            | kind == expected || kind == CoreNeverType -> collect next (core : done) rest
            | otherwise -> halt (locatedSpan argument) ("a " <> coreTypeName kind <> " argument to " <> member) next
  (after, Just (coreReceiver, CoreNeverType)) -> effects after [] arguments
    where
      -- The receiver still runs after the arguments, and it is what stops the call.
      effects current done [] = built current (CoreBlockValue (CoreBlock
        [CoreStatement (coreExpressionSpan operand) (CoreEvaluate operand) | operand <- reverse done <> [coreReceiver]] Nothing))
        CoreNeverType
      effects current done (argument : rest) = case lower current argument of
        (next, Nothing) -> refused next
        (next, Just (core, _))
          | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] method argument" next
          | otherwise -> effects next (core : done) rest
  (after, Just (_, kind)) -> halt at ("methods on " <> coreTypeName kind) after
 where
  built current shape kind = (current, Just (CoreExpression at kind shape, kind))

methods :: [(Text, (CoreTextMethodName, [CoreType], CoreType))]
methods =
  [ ("length", (TextLength, [], intType))
  , ("isEmpty", (TextIsEmpty, [], CoreBoolType))
  , ("contains", (TextContains, [CoreTextType], CoreBoolType))
  , ("startsWith", (TextStartsWith, [CoreTextType], CoreBoolType))
  , ("endsWith", (TextEndsWith, [CoreTextType], CoreBoolType))
  , ("indexOf", (TextIndexOf, [CoreTextType], intType))
  , ("spanOf", (TextSpanOf, [CoreTextType], intType))
  , ("spanNotOf", (TextSpanNotOf, [CoreTextType], intType))
  , ("drop", (TextDrop, [intType], CoreTextType))
  , ("take", (TextTake, [intType], CoreTextType))
  , ("slice", (TextSlice, [intType, intType], CoreTextType))
  , ("repeat", (TextRepeat, [intType], CoreTextType))
  , ("reverse", (TextReverse, [], CoreTextType))
  , ("escapeHtml", (TextEscapeHtml, [], CoreTextType))
  , ("replace", (TextReplace, [CoreTextType, CoreTextType], CoreTextType))
  ]
