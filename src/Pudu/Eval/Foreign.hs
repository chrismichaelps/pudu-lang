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
import Foreign.Ptr (Ptr)
import Pudu.Diagnostic
  ( Diagnostic
  , Severity (Error)
  , diagnostic
  , mkDiagnosticCode
  , withHelp
  )
import Pudu.Eval.Env (Evaluator, abortAt, currentForeignStore, performEffect)
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (..), defaultIntegerKind)
import Pudu.Eval.Value (ForeignBinding (..), ForeignRelease (..), Value (..))
import Pudu.Foreign.Call
  ( CrossedValue (..)
  , callSymbol
  , resolveSymbol
  )
import Pudu.Foreign.Crossing (Crossing (..), crossingName, fitsCrossing)
import Pudu.Foreign.Ownership
  ( ForeignResource
  , ForeignStore
  , claimOwned
  , restoreOwned
  , takeOwned
  , withOwned
  )
import Pudu.Source (Span)

{-| Make the call the binding describes.

    A foreign call is an effect, and the same rule applies to it as to reading a
    file: a compile-time constant is folded while the compiler runs, and letting
    one reach a graphics library would make what the program compiles to depend
    on what was installed on the machine that compiled it. -}
callForeign :: Span -> ForeignBinding -> [Value] -> Evaluator Value
callForeign spanValue binding values = do
  crossed <- crossArguments spanValue binding values
  store <- currentForeignStore
  found <-
    performEffect (refusal spanValue)
      (resolveSymbol (foreignBindingLibrary binding) (foreignBindingSymbol binding))
  case found of
    Left problem -> abortForeign spanValue binding problem
    Right symbol -> do
      released <- prepareHandles spanValue binding store crossed
      attempted <- invoke spanValue binding store symbol crossed
      case attempted of
        Nothing -> deadHandle spanValue binding (firstHandleName crossed)
        Just (Left problem) -> do
          restoreReleased spanValue store released
          abortForeign spanValue binding problem
        Just (Right result) -> receive spanValue binding store result

invoke
  :: Span
  -> ForeignBinding
  -> ForeignStore
  -> Ptr ()
  -> [(Crossing, CrossedValue)]
  -> Evaluator (Maybe (Either Text CrossedValue))
invoke spanValue binding store symbol arguments =
  case foreignBindingReleases binding of
    Just _ -> Just <$> perform
    Nothing ->
      performEffect (refusal spanValue)
        (withOwned store (map snd (handleAddresses arguments))
          (callSymbol symbol arguments (foreignBindingResult binding)))
 where
  perform =
    performEffect (refusal spanValue)
      (callSymbol symbol arguments (foreignBindingResult binding))

{-| Validate handle liveness immediately before control crosses the boundary.

    Releasing removes ownership before the call. That ordering closes the only
    window in which an aliased value could start a second release, while a
    failure to assemble the call restores the claim because foreign code never
    ran. -}
prepareHandles
  :: Span
  -> ForeignBinding
  -> ForeignStore
  -> [(Crossing, CrossedValue)]
  -> Evaluator (Maybe (Int64, ForeignResource))
prepareHandles spanValue binding store arguments =
  case foreignBindingReleases binding of
    Just expected -> case handleAddresses arguments of
      [(actual, address)]
        | actual == expected -> do
            released <- performEffect (refusal spanValue) (takeOwned store address)
            case released of
              Just resource -> pure (Just (address, resource))
              Nothing -> deadHandle spanValue binding actual
      _ ->
        abortAt (Just spanValue) "E7022"
          (foreignBindingSymbol binding <> " cannot release this handle")
          (Just "pass one live handle of the type named by its foreign declaration")
    Nothing -> pure Nothing

handleAddresses :: [(Crossing, CrossedValue)] -> [(Text, Int64)]
handleAddresses arguments =
  [ (name, address)
  | (_, CrossedHandle name address) <- arguments
  ]

restoreReleased :: Span -> ForeignStore -> Maybe (Int64, ForeignResource) -> Evaluator ()
restoreReleased _ _ Nothing = pure ()
restoreReleased spanValue store (Just (address, resource)) =
  performEffect (refusal spanValue) (restoreOwned store address resource)

firstHandleName :: [(Crossing, CrossedValue)] -> Text
firstHandleName arguments = case handleAddresses arguments of
  (name, _) : _ -> name
  [] -> "foreign handle"

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
receive :: Span -> ForeignBinding -> ForeignStore -> CrossedValue -> Evaluator Value
receive spanValue binding store produced =
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
      | otherwise -> case foreignBindingReleasedBy binding of
          Nothing -> foreignResultMismatch spanValue binding
          Just release -> do
            fresh <-
              performEffect (refusal spanValue)
                (claimOwned store address (releaseHandle release name address))
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

releaseHandle :: ForeignRelease -> Text -> Int64 -> IO ()
releaseHandle release name address = do
  found <- resolveSymbol (foreignReleaseLibrary release) (foreignReleaseSymbol release)
  case found of
    Left _ -> pure ()
    Right symbol -> do
      _ <- callSymbol symbol [(HandleCrossing name, CrossedHandle name address)] NothingCrossing
      pure ()

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
