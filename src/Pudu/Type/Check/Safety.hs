{-| @Type.Check.Safety — checks compile-time purity and unsafe capabilities -}
module Pudu.Type.Check.Safety
  ( checkComptimeCall
  , comptimeBuiltins
  , reportUnusedCapabilities
  , requireComptimePurity
  , dottedName
  ) where

import Control.Monad (unless, when)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Expression (..), Function (..))
import Pudu.Source (Span)
import Pudu.Type.Value (capabilityName)
import Pudu.Type.Env
  ( Checker
  , UnsafeFrame (..)
  , leaveUnsafe
  , warn
  , isComptimeFunction
  , inComptime
  , lookupName
  , report
  )

{-| A compile-time function runs in an evaluator with no IO, environment, time,
    randomness, unsafe, or task operations, so the shapes that could reach one
    are refused at the declaration rather than discovered when it runs. -}
requireComptimePurity :: Function -> Checker ()
requireComptimePurity value
  | not (functionComptime value) = pure ()
  | otherwise = do
      when (functionAsync value) $
        report "E3025" nameSpan
          ("comptime function " <> name <> " cannot be async")
          (Just "compile-time evaluation excludes task operations")
      case functionUnsafe value of
        Nothing -> pure ()
        Just _ ->
          report "E3025" nameSpan
            ("comptime function " <> name <> " cannot be unsafe")
            (Just "compile-time evaluation excludes unchecked operations")
 where
  name = locatedValue (functionName value)
  nameSpan = locatedSpan (functionName value)

{-| A compile-time body may call only other compile-time functions. The
    guarantee has to be transitive, or a pure-looking function could reach an
    arbitrary one and the evaluator would meet it at compile time. -}
checkComptimeCall :: Span -> Located Expression -> Checker ()
checkComptimeCall spanValue callee = do
  inside <- inComptime
  when inside $ case dottedName (locatedValue callee) of
    Just name -> do
      comptime <- isComptimeFunction name
      builtin <- pure (name `elem` comptimeBuiltins)
      {-| A dotted callee is only judged when the whole path names something.

          `Health.flagOf` is bound under that spelling and is a call this rule
          is about; `reading.counts` is a field of a value and is not, and
          neither is a built-in method on one. Asking whether the path binds
          tells the two apart without a second notion of what a module is. -}
      declared <- if comptime || builtin then pure True else isDeclaredName name
      unless (comptime || builtin || not declared) $
        report "E3025" spanValue
          ("comptime function cannot call " <> name)
          (Just "declare the callee comptime, or move the call out of compile-time code")
    _ -> pure ()

isDeclaredName :: Text -> Checker Bool
isDeclaredName name = maybe False (const True) <$> lookupName name

{-| Names a compile-time body may reach that are not user declarations. -}
comptimeBuiltins :: [Text]
comptimeBuiltins = ["Some", "None", "Ok", "Err", "panic", "charFromCode", "show", "display", "convertInteger"]

{-| A granted capability that the region never reached for is noise: it widens
    the audited surface without buying anything, so leaving the region reports
    it. -}
reportUnusedCapabilities :: Span -> Checker ()
reportUnusedCapabilities spanValue = do
  frame <- leaveUnsafe
  case frame of
    Nothing -> pure ()
    Just found -> do
      let granted = frameGranted found
          unused = [capability | capability <- granted, capability `notElem` frameUsed found]
      if null granted
        then
          when (null (frameUsed found)) $
            warn "W3001" spanValue "this unsafe region grants abilities nothing in it uses"
              (Just "remove the unsafe region, or name the capabilities the code needs")
        else
          unless (null unused) $
            warn "W3001" spanValue
              ("unsafe region grants unused " <> Text.intercalate ", " (map capabilityName unused))
              (Just "drop the capabilities the region does not need")

{-| A chain of names, written as a path or as member accesses, joined back into
    the dotted name it stands for. Anything else is not a name.

    The dotted spelling is the key the checker binds a name under, so asking
    about `Bindings.fold` finds the same declaration the call resolves against.
    A qualified call arrives here as member access rather than as a path, and
    matching only the undotted form was how a compile-time body could reach an
    ordinary function by naming its module. -}
dottedName :: Expression -> Maybe Text
dottedName expression = case expression of
  NameExpression names -> Just (Text.intercalate "." (NonEmpty.toList names))
  MemberExpression target member ->
    (\prefix -> prefix <> "." <> locatedValue member) <$> dottedName (locatedValue target)
  _ -> Nothing
