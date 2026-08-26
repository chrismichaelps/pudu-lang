{-| @Type.Check.Safety — checks compile-time purity and unsafe capabilities -}
module Pudu.Type.Check.Safety
  ( checkComptimeCall
  , checkUnsafeCall
  , comptimeBuiltins
  , reportUnusedCapabilities
  , requireComptimePurity
  ) where

import Control.Monad (unless, when)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Capability (..)
  , Expression (..)
  , Function (..)
  )
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker
  , UnsafeFrame (..)
  , insideUnsafe
  , leaveUnsafe
  , unsafeFunctionCapabilities
  , useCapability
  , useUnsafeRegion
  , warn
  , isComptimeFunction
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
checkComptimeCall :: Span -> Located Expression -> Checker ()
checkComptimeCall spanValue callee = do
  inside <- inComptime
  when inside $ case locatedValue callee of
    NameExpression (name NonEmpty.:| []) -> do
      comptime <- isComptimeFunction name
      builtin <- pure (name `elem` comptimeBuiltins)
      unless (comptime || builtin) $
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

capabilityName :: Capability -> Text
capabilityName capability = case capability of
  RawCapability -> "raw"
  ForeignCapability -> "foreign"
  UncheckedCapability -> "unchecked"
  NullCapability -> "null"

{-| Calling an unsafe function requires an unsafe context that grants what the
    declaration asked for. A blanket declaration requires only that some region
    is open; a declaration that names capabilities requires each of them, which
    is what makes the requirement auditable rather than all-or-nothing. -}
checkUnsafeCall :: Span -> Located Expression -> Checker ()
checkUnsafeCall spanValue callee = case locatedValue callee of
  NameExpression (name NonEmpty.:| []) -> do
    declaredCapabilities <- unsafeFunctionCapabilities name
    case declaredCapabilities of
      Nothing -> pure ()
      Just [] -> do
        open <- insideUnsafe
        if open
          then useUnsafeRegion
          else
            report "E3023" spanValue
              ("unsafe function " <> name <> " called outside an unsafe region")
              (Just "wrap the call in unsafe { ... }, or declare the caller unsafe")
      Just required -> mapM_ (requireCapability spanValue name) required
  _ -> pure ()

requireCapability :: Span -> Text -> Capability -> Checker ()
requireCapability spanValue name capability = do
  granted <- useCapability capability
  unless granted $
    report "E3023" spanValue
      ( "unsafe function " <> name <> " needs the "
          <> capabilityName capability <> " capability here"
      )
      ( Just
          ( "wrap the call in unsafe(" <> capabilityName capability
              <> ") { ... }, or declare the caller with that capability"
          )
      )
