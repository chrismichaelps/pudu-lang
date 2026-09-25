{-| @Eval.Place — where an assignment stores, and how a call hands back what it
    was lent.

    A place is a binding and the steps from it: a field by name, or an element
    by the position its index evaluated to. The steps are decided before the
    value to store is evaluated, so an index is evaluated once and a right-hand
    side that changes it does not move the write.

    A `&mut` argument lends a place. The callee is given the place's value, and
    when it finishes — by its last expression, `return`, or `?` — the final value
    of the parameter is stored back into the place. The checker keeps an
    exclusive reference out of every binding, field, closure, and result, and
    refuses overlapping loans, so no code can observe the place while the call
    runs and this is indistinguishable from writing through it. -}
module Pudu.Eval.Place
  ( Lent (..)
  , Place
  , exclusiveParameters
  , noneLent
  , placeOf
  , plainPlace
  , readPlace
  , storePlace
  , withFrameKeeping
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import qualified Data.Sequence as Seq
import Data.Text (Text)
import Pudu.Eval.Env (Env (..), Eval (..), Evaluator (..), abortAt, lookupName, updateExisting)
import Pudu.Eval.Operator (readIndex, readMember)
import Pudu.Eval.Render (valueKind)
import Pudu.Eval.Value (Value (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Expression (..)
  , Function (..)
  , Parameter (..)
  , TypeSyntax (..)
  )
import Pudu.Source (Span)

data Step = FieldStep !Text | ElementStep !Value

data Place = Place !Span !Text ![Step]

{-| The places a call's arguments were lent from, beside the receiver's. -}
data Lent = Lent
  { lentSelf :: !(Maybe Place)
  , lentArguments :: ![Maybe Place]
  }

noneLent :: Lent
noneLent = Lent{lentSelf = Nothing, lentArguments = []}

{-| The place an expression names, evaluating any index it chooses by. -}
placeOf :: (Located Expression -> Evaluator Value) -> Located Expression -> Evaluator (Maybe Place)
placeOf evaluate (Located spanValue expression) = case expression of
  NameExpression (root :| fields) -> pure (Just (Place spanValue root (map FieldStep fields)))
  MemberExpression target (Located _ field) -> fmap (extend (FieldStep field)) <$> placeOf evaluate target
  IndexExpression target index -> do
    base <- placeOf evaluate target
    case base of
      Nothing -> pure Nothing
      Just found -> do
        key <- evaluate index
        pure (Just (extend (ElementStep key) found))
  UnaryExpression "*" operand -> placeOf evaluate operand
  UnaryExpression "&mut" operand -> placeOf evaluate operand
  _ -> pure Nothing

{-| The place an expression names when finding it evaluates nothing. -}
plainPlace :: Located Expression -> Maybe Place
plainPlace (Located spanValue expression) = case expression of
  NameExpression (root :| fields) -> Just (Place spanValue root (map FieldStep fields))
  MemberExpression target (Located _ field) -> extend (FieldStep field) <$> plainPlace target
  UnaryExpression "*" operand -> plainPlace operand
  UnaryExpression "&mut" operand -> plainPlace operand
  _ -> Nothing

extend :: Step -> Place -> Place
extend step (Place spanValue root steps) = Place spanValue root (steps <> [step])

{-| What a place holds, read the way the expression naming it would be. -}
readPlace :: Place -> Evaluator Value
readPlace (Place spanValue root steps) = do
  found <- lookupName root
  case found of
    Nothing -> abortAt (Just spanValue) "E7001" ("undefined name " <> root) Nothing
    Just value -> follow value steps
 where
  follow value remaining = case remaining of
    [] -> pure value
    FieldStep field : rest -> readMember spanValue value field >>= \inner -> follow inner rest
    ElementStep key : rest -> readIndex spanValue value key >>= \inner -> follow inner rest

{-| Store a value into a place: the binding at its root is given a copy of what
    it held with the one field or element along the path replaced. -}
storePlace :: Place -> Value -> Evaluator ()
storePlace (Place spanValue root steps) value = do
  found <- lookupName root
  case found of
    Nothing -> abortAt (Just spanValue) "E7001" ("undefined name " <> root) Nothing
    Just current -> do
      replaced <- rebuild current steps
      stored <- updateExisting root replaced
      if stored
        then pure ()
        else abortAt (Just spanValue) "E7001" (root <> " is not a binding that can be assigned") Nothing
 where
  rebuild current remaining = case remaining of
    [] -> pure value
    FieldStep field : rest -> case current of
      RecordValue owner fields
        | Just inner <- lookup field fields -> do
            changed <- rebuild inner rest
            changed `seq`
              pure (RecordValue owner [(name, if name == field then changed else held) | (name, held) <- fields])
      _ ->
        abortAt (Just spanValue) "E7001"
          ("a " <> valueKind current <> " has no field " <> field <> " to assign") Nothing
    ElementStep key : rest -> case (current, key) of
      (ArrayValue members, IntValue _ position)
        | position >= 0 && position < toInteger (Seq.length members) -> do
            let index = fromInteger position
            changed <- rebuild (Seq.index members index) rest
            changed `seq` pure (ArrayValue (Seq.update index changed members))
        | otherwise -> abortAt (Just spanValue) "E7004" "index out of range" Nothing
      _ ->
        abortAt (Just spanValue) "E7001"
          ("an element of a " <> valueKind current <> " cannot be assigned") Nothing

{-| Run a function body in a frame of its parameters, answering the final value
    of the named ones beside the body's result. -}
withFrameKeeping :: [(Text, Value)] -> [Text] -> Evaluator a -> Evaluator (a, [Value])
withFrameKeeping bindings kept (Evaluator action) =
  Evaluator $ \env -> do
    outcome <- action env{envFrames = Map.fromList bindings : envFrames env}
    pure $ case outcome of
      Done value next -> case envFrames next of
        frame : rest -> Done (value, map (finalIn frame) kept) next{envFrames = rest}
        [] -> Done (value, map (finalIn Map.empty) kept) next
      Unwound transfer next -> Unwound transfer next{envFrames = drop 1 (envFrames next)}
      Aborted stop -> Aborted stop
 where
  finalIn frame name = Map.findWithDefault (maybe UnitValue id (lookup name bindings)) name frame

{-| The positions of a function's parameters declared `&mut`. -}
exclusiveParameters :: Function -> [Int]
exclusiveParameters function =
  [ position
  | (position, Located _ parameter) <- zip [0 ..] (functionParameters function)
  , exclusive (parameterType parameter)
  ]
 where
  exclusive written = case written of
    Just (Located _ (ReferenceType True _)) -> True
    _ -> False
