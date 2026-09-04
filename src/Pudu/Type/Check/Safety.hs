{-| @Type.Check.Safety — checks compile-time purity and unsafe capabilities -}
module Pudu.Type.Check.Safety
  ( checkComptimeCall
  , checkSuppliedArguments
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
import Pudu.Type.Value (Type (..), capabilityName)
import Pudu.Type.Env
  ( Checker
  , UnsafeFrame (..)
  , leaveUnsafe
  , warn
  , isComptimeFunction
  , requiredArityOf
  , inComptime
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
{-| Refuse a call that supplies fewer arguments than the declaration requires.

    A function type records what each parameter takes and not whether it has to
    be supplied, so the call rule reading only the type cannot tell an omitted
    default from a missing argument and accepts both. The count that decides it
    belongs to the declaration, and is asked for here by the name that reaches
    it: a name absent from that table is a parameter, a local, or a value
    obtained some other way, about which nothing is claimed.

    Too many arguments stays with the call rule, which knows the total from the
    type alone. -}
checkSuppliedArguments :: Span -> Located Expression -> Type -> Int -> Checker ()
checkSuppliedArguments spanValue callee calleeType supplied =
  case dottedName (locatedValue callee) of
    Nothing -> pure ()
    Just name -> do
      known <- requiredArityOf name
      case (known, parameterCount calleeType) of
        {-| The declaration is the one this call reached only when the type it
            was given takes as many parameters as that declaration writes. A
            name may be a parameter here and a declaration elsewhere, and the
            count is what tells them apart. -}
        (Just (required, total), Just written)
          | written == total && supplied < required ->
              report "E3003" spanValue
                ( "expected " <> countArguments required
                    <> ", found " <> countArguments supplied
                )
                (Just "pass one argument per parameter, or give the parameter a default")
        _ -> pure ()

{-| How many parameters this callee takes, looking through what a call already
    looks through. -}
parameterCount :: Type -> Maybe Int
parameterCount calleeType = case calleeType of
  RestrictedType _ inner -> parameterCount inner
  FunctionTypeValue _ inputs _ -> Just (length inputs)
  _ -> Nothing

countArguments :: Int -> Text
countArguments value
  | value == 1 = "1 argument"
  | otherwise = Text.pack (show value) <> " arguments"

checkComptimeCall :: Span -> Located Expression -> Checker ()
checkComptimeCall spanValue callee = do
  inside <- inComptime
  when inside $ case dottedName (locatedValue callee) of
    Just name -> do
      known <- isComptimeFunction name
      {-| Refused only when the callee is a declared function that may not fold.

          A name nothing is known about — a parameter, a local, a built-in
          method on a value — is left to the fold itself, which refuses an
          effect where it happens. Refusing those here bought no guarantee and
          made a compile-time function unable to call anything it was handed,
          so higher-order compile-time code could not be written at all. -}
      when (known == Just False && name `notElem` comptimeBuiltins) $
        report "E3025" spanValue
          ("comptime function cannot call " <> name)
          (Just "declare the callee comptime, or move the call out of compile-time code")
    _ -> pure ()

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
