{-| @Pudu.Compiler.Lower.Text — built-in Str and Char methods on a lowered receiver. -}
module Pudu.Compiler.Lower.Text (lowerTextMethod) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refused)
import Pudu.Compiler.Lower.Types (typeForSpan)
import Pudu.Core
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

{-| The receiver's type decides whether this is a Str method at all. Str
    answers its own methods before any impl, so there is no lookup to make. -}
lowerTextMethod :: LowerExpression -> LowerState -> Span -> Located Expression -> Text -> [Located Expression]
  -> (LowerState, Maybe (CoreExpression, CoreType))
lowerTextMethod lower state at receiver member arguments = case lower state receiver of
  (after, Nothing) -> refused after
  (after, Just (coreReceiver, CoreTextType))
    | null arguments, Just reading <- lookup member parsers -> parsed after coreReceiver reading
    | otherwise -> case lookup member methods of
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
  (after, Just (coreReceiver, CoreCharType)) -> case (member, arguments) of
    -- Char answers these two before any impl, as readCharMember does.
    ("code", []) -> built after (CoreCharCode coreReceiver) intType
    ("toText", []) -> built after (CoreDisplay coreReceiver) CoreTextType
    _ | member `elem` ["code", "toText"] -> halt at ("a call to " <> member <> " with this many arguments") after
      | otherwise -> halt at ("the Char method '" <> member <> "'") after
  (after, Just (_, kind)) -> halt at ("methods on " <> coreTypeName kind) after
 where
  built current shape kind = (current, Just (CoreExpression at kind shape, kind))

  -- toInt/toFloat: the text goes into a local, then a test picks Some(read)
  -- or None, using the Option the checker gave the call.
  parsed current coreReceiver (test, readName, valueType) = case typeForSpan (contextTypes (lowerContext current)) at of
    Just kind@(CoreSumType _ _) ->
      let (withHeld, held) = bindLocal current "" CoreTextType
          expression shape' kind' = CoreExpression at kind' shape'
          text' = expression (CoreReadLocal held) CoreTextType
          some = expression (CoreConstruct "Some" [("0", expression (CoreTextMethod readName text' []) valueType)]) kind
          none = expression (CoreConstruct "None" []) kind
          choice = expression (CoreIfValue (expression (CoreTextMethod test text' []) CoreBoolType) (CoreBlock [] (Just some)) none) kind
       in built withHeld (CoreBlockValue (CoreBlock [CoreStatement at (CoreDeclare held coreReceiver)] (Just choice))) kind
    _ -> halt at ("an Option result of " <> member <> " without a native form") current

parsers :: [(Text, (CoreTextMethodName, CoreTextMethodName, CoreType))]
parsers =
  [ ("toInt", (TextParsesInt, TextIntOf, intType))
  , ("toFloat", (TextParsesFloat, TextFloatOf, CoreFloatType Float64Width))
  ]

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
  , ("trim", (TextTrim, [], CoreTextType))
  , ("toUpper", (TextToUpper, [], CoreTextType))
  , ("toLower", (TextToLower, [], CoreTextType))
  , ("charAt", (TextCharAt, [intType], CoreCharType))
  , ("split", (TextSplit, [CoreTextType], CoreArrayType CoreTextType))
  , ("lines", (TextLines, [], CoreArrayType CoreTextType))
  , ("chars", (TextChars, [], CoreArrayType CoreCharType))
  ]
