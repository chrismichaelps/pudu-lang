{-| @Eval.Foreign — makes a call into a library written elsewhere

    Everything the declaration promised is enforced here, on the way through.
    That order matters: past this point the value is in somebody else's hands
    and a mistake stops being a diagnostic and becomes a corrupted stack, so
    every check that can happen before the call happens before the call. -}
module Pudu.Eval.Foreign
  ( callForeign
  ) where

import Data.Maybe (fromMaybe)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic
  ( Diagnostic
  , Severity (Error)
  , diagnostic
  , mkDiagnosticCode
  , withHelp
  )
import Pudu.Eval.Env (Evaluator, abortAt, performEffect)
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (..), defaultIntegerKind)
import Pudu.Eval.Value (ForeignBinding (..), Value (..))
import Pudu.Foreign.Call
  ( CrossedValue (..)
  , callSymbol
  , claimOwned
  , findSymbol
  , openLibrary
  , ownsAddress
  , releaseOwned
  )
import Pudu.Foreign.Crossing (Crossing (..), crossingName, fitsCrossing)
import Pudu.Source (Span)

{-| Make the call the binding describes.

    A foreign call is an effect, and the same rule applies to it as to reading a
    file: a compile-time constant is folded while the compiler runs, and letting
    one reach a graphics library would make what the program compiles to depend
    on what was installed on the machine that compiled it. -}
callForeign :: Span -> ForeignBinding -> [Value] -> Evaluator Value
callForeign spanValue binding values = do
  crossed <- crossArguments spanValue binding values
  opened <-
    performEffect (refusal spanValue) (openLibrary (foreignBindingLibrary binding))
  case opened of
    Left problem -> abortForeign spanValue binding problem
    Right handle -> do
      found <-
        performEffect (refusal spanValue) (findSymbol handle (foreignBindingSymbol binding))
      case found of
        Left problem -> abortForeign spanValue binding problem
        Right symbol -> do
          released <- prepareHandles spanValue binding crossed
          produced <-
            performEffect (refusal spanValue)
              (callSymbol symbol crossed (foreignBindingResult binding))
          case produced of
            Left problem -> do
              restoreReleased spanValue released
              abortForeign spanValue binding problem
            Right result -> receive spanValue binding result

{-| Validate handle liveness immediately before control crosses the boundary.

    Releasing removes ownership before the call. That ordering closes the only
    window in which an aliased value could start a second release, while a
    failure to assemble the call restores the claim because foreign code never
    ran. -}
prepareHandles
  :: Span
  -> ForeignBinding
  -> [(Crossing, CrossedValue)]
  -> Evaluator (Maybe Int64)
prepareHandles spanValue binding arguments =
  case foreignBindingReleases binding of
    Just expected -> case handleAddresses arguments of
      [(actual, address)]
        | actual == expected -> do
            released <- performEffect (refusal spanValue) (releaseOwned address)
            if released
              then pure (Just address)
              else deadHandle spanValue binding actual
      _ ->
        abortAt (Just spanValue) "E7022"
          (foreignBindingSymbol binding <> " cannot release this handle")
          (Just "pass one live handle of the type named by its foreign declaration")
    Nothing -> do
      live <-
        performEffect (refusal spanValue)
          (mapM (ownsAddress . snd) (handleAddresses arguments))
      case [name | ((name, _), False) <- zip (handleAddresses arguments) live] of
        name : _ -> deadHandle spanValue binding name
        [] -> pure Nothing

handleAddresses :: [(Crossing, CrossedValue)] -> [(Text, Int64)]
handleAddresses arguments =
  [ (name, address)
  | (_, CrossedHandle name address) <- arguments
  ]

restoreReleased :: Span -> Maybe Int64 -> Evaluator ()
restoreReleased _ Nothing = pure ()
restoreReleased spanValue (Just address) = do
  _ <- performEffect (refusal spanValue) (claimOwned address)
  pure ()

deadHandle :: Span -> ForeignBinding -> Text -> Evaluator a
deadHandle spanValue binding name =
  abortAt (Just spanValue) "E7022"
    ("the " <> name <> " passed to " <> foreignBindingSymbol binding <> " is no longer owned")
    (Just "a foreign handle cannot be used or released after its release function has run")

{-| Narrow each argument to what the declaration said it crosses as.

    An integer that does not fit the declared width is refused rather than
    wrapped. Silent wraparound at this boundary is the oldest way for a program
    calling a library to keep running with a value it never computed. -}
crossArguments :: Span -> ForeignBinding -> [Value] -> Evaluator [(Crossing, CrossedValue)]
crossArguments spanValue binding values
  | length expected /= length values =
      abortAt (Just spanValue) "E7016"
        ( foreignBindingSymbol binding <> " takes "
            <> count (length expected) <> " but was given "
            <> Text.pack (show (length values))
        )
        (Just "the declaration in the foreign block says how many it takes")
  | otherwise = mapM (uncurry (crossOne spanValue binding)) (zip expected values)
 where
  expected = foreignBindingArguments binding

count :: Int -> Text
count value
  | value == 1 = "1 argument"
  | otherwise = Text.pack (show value) <> " arguments"

crossOne :: Span -> ForeignBinding -> Crossing -> Value -> Evaluator (Crossing, CrossedValue)
crossOne spanValue binding crossing value = case (crossing, value) of
  (TextCrossing, StrValue written)
    | Text.any (== '\0') written ->
        abortAt (Just spanValue) "E7017"
          "text carrying a nought cannot cross a foreign boundary"
          ( Just
              ( "the other side reads until the first nought, so it would see "
                  <> "less than this text says"
              )
          )
    | otherwise -> pure (crossing, CrossedText written)
  (FloatingCrossing _, FloatValue _ held) -> pure (crossing, CrossedDouble held)
  (BooleanCrossing, BoolValue held) -> pure (crossing, CrossedInteger (if held then 1 else 0))
  (HandleCrossing expected, ForeignHandleValue actual address)
    | expected == actual -> pure (crossing, CrossedHandle actual address)
  (_, IntValue _ held)
    | isIntegral crossing ->
        if fitsCrossing crossing held
          then pure (crossing, CrossedInteger (fromIntegral held))
          else
            abortAt (Just spanValue) "E7018"
              ( Text.pack (show held) <> " does not fit the "
                  <> crossingName crossing <> " this argument crosses as"
              )
              ( Just
                  ( "a value that does not fit would arrive as a different value; "
                      <> "widen the declaration or narrow what is passed"
                  )
              )
  _ ->
    abortAt (Just spanValue) "E7019"
      ( "this argument to " <> foreignBindingSymbol binding
          <> " is not the " <> crossingName crossing <> " it crosses as"
      )
      (Just "pass what the foreign declaration names")

isIntegral :: Crossing -> Bool
isIntegral crossing = case crossing of
  SignedCrossing _ -> True
  UnsignedCrossing _ -> True
  _ -> False

{-| What comes back, as a value of this language.

    A width goes out and an ordinary integer comes back: the declaration decides
    how much of a number crosses, and nothing above the boundary carries a
    machine width it did not ask for. -}
receive :: Span -> ForeignBinding -> CrossedValue -> Evaluator Value
receive spanValue binding produced =
  case (foreignBindingResult binding, produced) of
    (NothingCrossing, _) -> pure UnitValue
    (BooleanCrossing, CrossedInteger held) -> pure (BoolValue (held /= 0))
    (FloatingCrossing _, CrossedDouble held) ->
      pure (FloatValue (widthOf (foreignBindingResult binding)) held)
    (HandleCrossing name, CrossedHandle actual address)
      | name /= actual -> foreignResultMismatch spanValue binding
      | address == 0 ->
          abortAt (Just spanValue) "E7020"
            (foreignBindingSymbol binding <> " returned a null " <> name)
            (Just "an owned foreign result must name a live object")
      | foreignBindingReleasedBy binding == Nothing ->
          foreignResultMismatch spanValue binding
      | otherwise -> do
          fresh <- performEffect (refusal spanValue) (claimOwned address)
          if fresh
            then pure (ForeignHandleValue name address)
            else
              abortAt (Just spanValue) "E7021"
                (foreignBindingSymbol binding <> " returned a " <> name <> " already owned")
                (Just "an owned foreign result must transfer one new ownership claim")
    (_, CrossedInteger held) ->
      pure (IntValue (kindOf (foreignBindingResult binding)) (fromIntegral held))
    (_, CrossedDouble held) ->
      pure (FloatValue (widthOf (foreignBindingResult binding)) held)
    (TextCrossing, CrossedText written) -> pure (StrValue written)
    _ -> foreignResultMismatch spanValue binding

foreignResultMismatch :: Span -> ForeignBinding -> Evaluator a
foreignResultMismatch spanValue binding =
  abortAt (Just spanValue) "E7015"
    (foreignBindingSymbol binding <> " returned a value outside its declaration")
    (Just "check the foreign result type against the library's exported signature")

kindOf :: Crossing -> IntegerKind
kindOf crossing = case crossing of
  SignedCrossing width -> SignedKind width
  UnsignedCrossing width -> UnsignedKind width
  _ -> defaultIntegerKind

widthOf :: Crossing -> FloatWidth
widthOf crossing = case crossing of
  FloatingCrossing 32 -> Float32Width
  _ -> Float64Width

abortForeign :: Span -> ForeignBinding -> Text -> Evaluator a
abortForeign spanValue binding problem =
  abortAt (Just spanValue) "E7015"
    ( "cannot call " <> foreignBindingSymbol binding <> " in "
        <> foreignBindingLibrary binding <> ": " <> problem
    )
    ( Just
        ( "a foreign declaration names a library the platform must already have; "
            <> "install it, or check the name and the symbol against what it exports"
        )
    )

refusal :: Span -> Diagnostic
refusal spanValue =
  fromMaybe (fallback spanValue) $ do
    code <- mkDiagnosticCode "E7009"
    value <- diagnostic code Error spanValue "a foreign call reaches outside the program"
    pure
      ( withHelp
          "a compile-time constant is folded while the compiler runs, so it cannot reach a library"
          value
      )

fallback :: Span -> Diagnostic
fallback spanValue =
  fromMaybe
    (error "the refusal diagnostic must exist")
    (mkDiagnosticCode "E7009" >>= \code -> diagnostic code Error spanValue "foreign call refused")
