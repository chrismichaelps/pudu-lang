{-| @Pudu.Compiler.Lower.Markup — page markup built from literals alone,
    kept after its first build.

    A call into `Std.Html` or `Std.Html.Build` that answers a page or a
    builder node, and whose every operand is a literal, a collection of
    literals, a kept constant or another such call, builds the same value
    every time: those functions reach nothing outside the program, and the
    value never changes. Such a call is kept like a module constant, under its
    call site and type, so a page's static parts are built once per run. -}
module Pudu.Compiler.Lower.Markup (keepMarkup) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.State (LowerState)
import Pudu.Core
import Pudu.Source (Span)

{-| A lowered call into the markup modules, kept when it is closed. -}
keepMarkup :: Span -> (LowerState, Maybe (CoreExpression, CoreType)) -> (LowerState, Maybe (CoreExpression, CoreType))
keepMarkup at lowered = case lowered of
  (state, Just (core, kind))
    | CoreCall callee _ <- coreExpressionShape core
    , markupFunction callee, markupType kind, closed core, size core >= 4 ->
        (state, Just (CoreExpression at kind (CoreConstant (key kind) core), kind))
  _ -> lowered
 where
  key kind = "markup " <> Text.pack (show at) <> " : " <> Text.pack (show kind)

{-| Functions of `Std.Html` and `Std.Html.Build`, which build values and reach
    nothing outside the program. -}
markupFunction :: Text -> Bool
markupFunction name = case Text.stripPrefix "Std.Html." name of
  Just rest -> not (Text.any (== '.') rest) || "Build." `Text.isPrefixOf` rest
  Nothing -> False

markupType :: CoreType -> Bool
markupType kind = case kind of
  CoreSumType name _ -> name == "Std.Html.Html"
  CoreRecordType name _ -> name == "Std.Html.Build.Node"
  _ -> False

{-| Built from literals, collections of them, kept constants and closed
    markup calls alone. -}
closed :: CoreExpression -> Bool
closed expression = case coreExpressionShape expression of
  CoreIntegerLiteral{} -> True
  CoreFloatLiteral{} -> True
  CoreDecimalLiteral{} -> True
  CoreBoolLiteral{} -> True
  CoreTextLiteral{} -> True
  CoreCharLiteral{} -> True
  CoreConstant{} -> True
  CoreArray items -> all closed items
  CoreTuple items -> all closed items
  CoreRecord fields -> all (closed . snd) fields
  CoreConstruct _ fields -> all (closed . snd) fields
  CoreCall name arguments -> markupFunction name && all closed arguments
  CoreBlockValue (CoreBlock [] (Just result)) -> closed result
  _ -> False

{-| How many expressions a closed value is built from, so a call too small to
    gain is left alone. -}
size :: CoreExpression -> Int
size expression = 1 + case coreExpressionShape expression of
  CoreArray items -> sum (map size items)
  CoreTuple items -> sum (map size items)
  CoreRecord fields -> sum (map (size . snd) fields)
  CoreConstruct _ fields -> sum (map (size . snd) fields)
  CoreCall _ arguments -> sum (map size arguments)
  CoreBlockValue (CoreBlock [] (Just result)) -> size result
  _ -> 0
